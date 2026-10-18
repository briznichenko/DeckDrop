#
#  test_frontend.py
#  DeckDrop
#
#  Created by Andrii Bryzhnychenko on 10/17/26.
#

import importlib.util
import os
from pathlib import Path
import sys
import time
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import test_protocol as protocol_tests

HAS_QT = importlib.util.find_spec("PySide6") is not None
if HAS_QT:
    from PySide6.QtCore import QCoreApplication, QEvent, QMetaObject, QObject, QUrl
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QQmlApplicationEngine
    from PySide6.QtQuick import QQuickWindow
    from PySide6.QtTest import QTest
    from deckdrop.presentation.controller import Controller


@unittest.skipUnless(HAS_QT and os.environ.get("DECKDROP_SERVER_BINARY"), "Requires Qt for Python and the Swift server harness")
class FrontendTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
        cls.app = QGuiApplication.instance() or QGuiApplication([])

    def wait_until(self, predicate, timeout=10):
        deadline = time.monotonic() + timeout
        while not predicate() and time.monotonic() < deadline:
            QTest.qWait(20)
        self.assertTrue(predicate(), "Frontend did not reach the expected state")

    def test_pair_choose_destination_and_copy_through_qml(self):
        fixture = protocol_tests.SwiftIntegrationTests()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        controller = Controller()
        engine = QQmlApplicationEngine()
        engine.setInitialProperties({"backend": controller})
        engine.load(QUrl.fromLocalFile(str(Path(__file__).resolve().parents[1] / "deckdrop/presentation/qml/Main.qml")))
        self.assertTrue(engine.rootObjects())
        window = engine.rootObjects()[0]
        try:
            QTest.qWait(150)
            window.grabWindow().save("/tmp/deckdrop-deck-unpaired.png")
            input_field = window.findChild(QObject, "pairingInput")
            connect_button = window.findChild(QObject, "connectButton")
            copy_button = window.findChild(QObject, "startCopyButton")
            self.assertFalse(copy_button.property("enabled"))
            link = fixture.pairing
            input_field.setProperty("text", f"deckdrop://{link.host}:{link.port}/#{link.token}.{link.fingerprint}")
            self.assertTrue(connect_button.property("enabled"))
            QMetaObject.invokeMethod(connect_button, "clicked")
            self.wait_until(lambda: controller.paired and not controller.busy)
            self.assertEqual(input_field.property("text"), "")
            self.assertFalse(copy_button.property("enabled"))
            destination = fixture.root / "Downloads"
            destination.mkdir()
            controller.chooseDestination(QUrl.fromLocalFile(str(destination)))
            self.assertTrue(copy_button.property("enabled"))
            QTest.qWait(150)
            window.grabWindow().save("/tmp/deckdrop-deck-ready.png")
            window.setWidth(960)
            window.setHeight(640)
            QTest.qWait(150)
            window.grabWindow().save("/tmp/deckdrop-deck-small.png")
            window.setWidth(1280)
            window.setHeight(800)
            QMetaObject.invokeMethod(copy_button, "clicked")
            self.wait_until(lambda: controller.state == "complete" and not controller.busy)
            self.assertEqual((destination / "Games/nested/日本語 save.bin").read_bytes(), fixture.payload)
            QTest.qWait(150)
            window.grabWindow().save("/tmp/deckdrop-deck-complete.png")
        finally:
            if controller.busy:
                controller.cancel()
                self.wait_until(lambda: not controller.busy, timeout=20)
            engine.deleteLater()
            QCoreApplication.sendPostedEvents(None, QEvent.DeferredDelete)
