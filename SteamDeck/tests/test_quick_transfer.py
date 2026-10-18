import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import pair
import test_protocol as protocol_tests
from deckdrop.transfer.protocol import TransferError


@unittest.skipUnless(os.environ.get("DECKDROP_SERVER_BINARY") and importlib.util.find_spec("PySide6"), "Requires Swift server and Qt for Python")
class QuickTransferTests(unittest.TestCase):
    def setUp(self):
        self.fixture = protocol_tests.SwiftIntegrationTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        link = self.fixture.pairing
        self.invitation = f"deckdrop://127.0.0.1:{link.port}/#{link.token}.{link.fingerprint}"
        self.destination = self.fixture.root / "card with spaces"
        self.destination.mkdir()
        self.environment = patch.dict(os.environ, {"SSH_CONNECTION": "127.0.0.1 12345 127.0.0.1 22"})
        self.environment.start()
        self.addCleanup(self.environment.stop)

        self.runtime = self.fixture.root / "runtime"
        self.runtime.mkdir(mode=0o700)
        self.receiver = subprocess.Popen([sys.executable, "-c", """
import os,sys
from PySide6.QtCore import QCoreApplication
from deckdrop.presentation.controller import Controller
from deckdrop.services.pairing import PairingInbox
app=QCoreApplication([])
c=Controller()
inbox=PairingInbox(c,sys.argv[1])
inbox.listen()
app.exec()
""", str(self.runtime / "deckdrop-receiver.sock")],
            cwd=Path(__file__).resolve().parents[1], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        self.addCleanup(self.stop_receiver)
        deadline = time.monotonic() + 5
        while not (self.runtime / "deckdrop-receiver.sock").exists() and time.monotonic() < deadline:
            time.sleep(.02)
        self.assertTrue((self.runtime / "deckdrop-receiver.sock").exists())
        self.desktop = patch.object(pair, "desktop_environment", return_value={"XDG_RUNTIME_DIR": str(self.runtime)})
        self.desktop.start()
        self.addCleanup(self.desktop.stop)

    def stop_receiver(self):
        self.receiver.terminate()
        self.receiver.communicate(timeout=5)

    def request(self, **updates):
        return {"action": "transfer", "invitation": self.invitation,
                "destination": str(self.destination), **updates}

    def test_confirmed_copy_and_repeat_preserve_existing_folder(self):
        for name in ("Games", "Games (2)"):
            reply = pair.pair(self.request())
            self.assertTrue(reply["completed"])
            final = Path(reply["path"])
            self.assertEqual(final.name, name)
            self.assertEqual((final / "nested/日本語 save.bin").read_bytes(), self.fixture.payload)
            self.assertTrue((final / "empty-folder").is_dir())
            self.assertEqual((final / "empty.txt").read_bytes(), b"")
        self.assertTrue((self.destination / "Games").is_dir())

    def test_missing_or_invalid_destination_does_not_fall_back(self):
        for destination in ("", "relative/path", str(self.destination / "missing")):
            with self.subTest(destination=destination), self.assertRaises(TransferError):
                pair.pair(self.request(destination=destination))
        self.assertEqual(list(self.destination.iterdir()), [])

    def test_wrong_certificate_does_not_create_copy(self):
        wrong = self.invitation.replace(self.fixture.pairing.fingerprint, "0" * 64)
        with self.assertRaisesRegex(TransferError, "certificate"):
            pair.pair(self.request(invitation=wrong))
        self.assertEqual(list(self.destination.iterdir()), [])

    def test_command_reports_completion_only_after_copy(self):
        command = [sys.executable, "-c", "import sys,pair; pair.desktop_environment=lambda: {'XDG_RUNTIME_DIR':sys.argv[1]}; pair.main()", str(self.runtime)]
        process = subprocess.run(command, cwd=Path(__file__).resolve().parents[1],
                                 input=json.dumps(self.request()) + "\n",
                                 text=True, capture_output=True, timeout=20)
        self.assertEqual(process.returncode, 0)
        events = [json.loads(line) for line in process.stdout.splitlines()]
        reply = events[-1]
        progress = events[:-1]
        self.assertTrue(progress)
        self.assertTrue(all(event["type"] == "progress" for event in progress))
        self.assertEqual(progress[-1]["completedBytes"], progress[-1]["totalBytes"])
        self.assertEqual(progress[-1]["currentFile"], "Done")
        self.assertTrue(reply["completed"])
        self.assertTrue(Path(reply["path"]).is_dir())
        process = subprocess.run(command, cwd=Path(__file__).resolve().parents[1],
                                 input=json.dumps(self.request(destination="missing")) + "\n",
                                 text=True, capture_output=True, timeout=20)
        reply = json.loads(process.stdout)
        self.assertFalse(reply["paired"])
        self.assertNotIn("completed", reply)
        self.assertIn("error", reply)
