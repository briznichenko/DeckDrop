import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import test_protocol as protocol_tests

HAS_QT = importlib.util.find_spec("PySide6") is not None
if HAS_QT:
    from PySide6.QtCore import QCoreApplication
    from PySide6.QtNetwork import QLocalSocket
    from PySide6.QtTest import QTest
    from deckdrop.controller import Controller
    from deckdrop.pairing import PairingInbox


@unittest.skipUnless(HAS_QT, "Requires Qt for Python")
class PairingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QCoreApplication.instance() or QCoreApplication([])

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.controller = Controller()
        self.inbox = PairingInbox(self.controller, str(Path(self.temporary.name) / "receiver.sock"))
        self.inbox.listen()
        self.addCleanup(self.inbox.close)

    def request(self, payload):
        client = QLocalSocket()
        client.connectToServer(self.inbox.path)
        self.assertTrue(client.waitForConnected(1000))
        client.write(payload)
        client.flush()
        data = bytearray()
        deadline = time.monotonic() + 20
        while b"\n" not in data and time.monotonic() < deadline:
            QTest.qWait(20)
            data.extend(bytes(client.readAll()))
        client.abort()
        self.assertIn(b"\n", data, "Receiver never acknowledged pairing")
        return json.loads(bytes(data).split(b"\n", 1)[0])

    def test_malformed_request_is_rejected(self):
        for payload in (b"[]\n", b"{\n", b'{"invitation":"bad"}\n', b"x" * 4097):
            with self.subTest(payload=payload[:50]):
                self.assertFalse(self.request(payload)["paired"])
        self.assertFalse(self.controller.busy)

    def test_busy_receiver_keeps_current_operation(self):
        self.controller._busy = True
        invitation = f"deckdrop://127.0.0.1:12345/#{'a' * 43}.{'b' * 64}"
        reply = self.request(json.dumps({"invitation": invitation}).encode() + b"\n")
        self.assertFalse(reply["paired"])
        self.assertIn("busy", reply["error"])
        self.assertTrue(self.controller.busy)
        self.assertEqual(self.controller._invitation, "")

    @unittest.skipUnless(os.environ.get("DECKDROP_SERVER_BINARY"), "Requires Swift server")
    def test_confirmation_requires_verified_mac(self):
        fixture = protocol_tests.SwiftIntegrationTests()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        pairing = fixture.pairing
        invitation = f"deckdrop://{pairing.host}:{pairing.port}/#{pairing.token}.{pairing.fingerprint}"
        reply = self.request(json.dumps({"invitation": invitation}).encode() + b"\n")
        self.assertTrue(reply["paired"])
        self.assertEqual(self.controller.folderName, "Games")
        self.assertFalse(self.controller.busy)
        wrong = invitation.replace(pairing.fingerprint, "0" * 64)
        reply = self.request(json.dumps({"invitation": wrong}).encode() + b"\n")
        self.assertFalse(reply["paired"])
        self.assertIn("certificate", reply["error"])
        self.assertFalse(self.controller.paired)


if __name__ == "__main__":
    unittest.main()
