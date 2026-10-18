#
#  test_protocol.py
#  DeckDrop
#
#  Created by Andrii Bryzhnychenko on 10/17/26.
#

import hashlib
import http.client
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from dataclasses import replace

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from deckdrop.transfer.protocol import Cancelled, Client, Pairing, PinnedConnection, TransferError, validate_manifest


class ProtocolTests(unittest.TestCase):
    def test_pairing_link_validation(self):
        valid = f"deckdrop://192.168.1.10:12345/#{'a' * 43}.{'b' * 64}"
        self.assertEqual(Pairing.parse(valid).host, "192.168.1.10")
        for malformed in ["", "http://192.168.1.10", valid.replace("12345", "70000"), valid + "extra", valid.replace("192.168.1.10", "user@192.168.1.10")]:
            with self.subTest(malformed=malformed), self.assertRaises(TransferError):
                Pairing.parse(malformed)

    def test_manifest_rejects_path_traversal_and_collisions(self):
        for path in ["../escape", "/absolute", "nested/../../escape", "a\\b", "a//b", "a/./b", "a\x00b"]:
            with self.subTest(path=path), self.assertRaises(TransferError):
                validate_manifest({"name": "Folder", "directories": [], "files": [{"id": 0, "path": path, "size": 1}]})
        for files in [
            [{"id": 0, "path": "a", "size": -1}],
            [{"id": 0, "path": "a", "size": True}],
            [{"id": 0, "path": "a", "size": 1}, {"id": 1, "path": "a/b", "size": 1}],
            [{"id": 0, "path": "a", "size": 1}, {"id": 0, "path": "b", "size": 1}],
        ]:
            with self.subTest(files=files), self.assertRaises(TransferError):
                validate_manifest({"name": "Folder", "directories": [], "files": files})

    def test_cancel_before_copy_creates_nothing(self):
        event = threading.Event()
        event.set()
        client = Client(Pairing("127.0.0.1", 1, "a" * 43, "b" * 64), event)
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(Cancelled):
                client.download({"name": "Folder", "directories": [], "files": []}, Path(directory), lambda *_: None)
            self.assertEqual(list(Path(directory).iterdir()), [])


@unittest.skipUnless(os.environ.get("DECKDROP_SERVER_BINARY"), "Set DECKDROP_SERVER_BINARY to run the real Swift HTTPS server tests")
class SwiftIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "Games"
        self.source.mkdir()
        (self.source / "empty-folder").mkdir()
        (self.source / "nested").mkdir()
        self.payload = os.urandom(3 * 1024 * 1024 + 17)
        (self.source / "nested/日本語 save.bin").write_bytes(self.payload)
        (self.source / "empty.txt").write_bytes(b"")
        self.outside = self.root / "private.txt"
        self.outside.write_text("must not be shared")
        (self.source / "outside-link").symlink_to(self.outside)
        invitation = self.root / "invitation"
        self.stop = self.root / "stop"
        self.process = subprocess.Popen([os.environ["DECKDROP_SERVER_BINARY"], str(self.source), str(invitation), str(self.stop)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.addCleanup(self.kill_server)
        deadline = time.monotonic() + 15
        while not invitation.exists() and time.monotonic() < deadline:
            if self.process.poll() is not None:
                self.fail(f"Swift server exited: {self.process.stderr.read().decode()}")
            time.sleep(.05)
        self.assertTrue(invitation.exists(), "Swift server did not start")
        self.pairing = Pairing.parse(invitation.read_text())
        self.client = Client(self.pairing)

    def kill_server(self):
        if self.process.poll() is None:
            self.process.terminate()
        self.process.communicate(timeout=5)

    def test_encrypted_copy_preserves_bytes_empty_folders_and_existing_destination(self):
        manifest = self.client.manifest()
        self.assertNotIn("outside-link", [f["path"] for f in manifest["files"]])
        destination = self.root / "Downloads"
        destination.mkdir()
        (destination / "Games").mkdir()
        (destination / "Games/existing.txt").write_text("keep")
        final = self.client.download(manifest, destination, lambda *_: None)
        self.assertEqual(final.name, "Games (2)")
        self.assertEqual((final / "nested/日本語 save.bin").read_bytes(), self.payload)
        self.assertEqual((destination / "Games/existing.txt").read_text(), "keep")
        self.assertTrue((final / "empty-folder").is_dir())
        self.assertEqual((final / "empty.txt").stat().st_size, 0)

    def test_response_is_not_truncated_when_receiver_reads_slowly(self):
        manifest = self.client.manifest()
        file = next(file for file in manifest["files"] if file["size"] > 0)
        connection, response = self.client.request(f"/files/{file['id']}")
        try:
            time.sleep(.15)
            received = bytearray()
            while chunk := response.read(65536):
                received.extend(chunk)
                time.sleep(.002)
            self.assertEqual(bytes(received), self.payload)
        finally:
            connection.close()

    def test_wrong_certificate_is_rejected_before_authorization(self):
        client = Client(replace(self.pairing, fingerprint="0" * 64))
        with self.assertRaisesRegex(TransferError, "certificate"):
            client.manifest()

    def test_wrong_token_is_rejected(self):
        with self.assertRaisesRegex(TransferError, "expired"):
            Client(replace(self.pairing, token="x" * 43)).manifest()

    def test_cancelled_transfer_never_publishes_completed_folder(self):
        manifest = self.client.manifest()
        destination = self.root / "Downloads"
        destination.mkdir()
        def cancel(*_):
            self.client.cancelled.set()
        with self.assertRaises(Cancelled):
            self.client.download(manifest, destination, cancel)
        self.assertFalse((destination / "Games").exists())
        self.assertTrue(any(".incomplete-" in p.name for p in destination.iterdir()))
        self.assertFalse(list(destination.rglob("*.partial")))

    def test_parent_symlink_replacement_cannot_read_outside_folder(self):
        manifest = self.client.manifest()
        file = next(f for f in manifest["files"] if f["path"].startswith("nested/"))
        (self.source / "nested").rename(self.source / "moved")
        outside = self.root / "outside"
        outside.mkdir()
        (outside / "日本語 save.bin").write_bytes(self.payload)
        (self.source / "nested").symlink_to(outside, target_is_directory=True)
        with self.assertRaises((TransferError, http.client.HTTPException)):
            self.client.request(f"/files/{file['id']}")

    def test_stop_revokes_existing_link(self):
        self.client.manifest()
        self.stop.touch()
        self.process.wait(timeout=5)
        with self.assertRaises((OSError, http.client.HTTPException)):
            self.client.manifest()


if __name__ == "__main__":
    unittest.main()
