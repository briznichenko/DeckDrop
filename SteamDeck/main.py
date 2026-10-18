#!/usr/bin/env python3
#
#  main.py
#  DeckDrop
#
#  Created by Andrii Bryzhnychenko on 10/17/26.
#

import os
from pathlib import Path
import sys

os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from PySide6.QtCore import QCoreApplication, QEvent, QLockFile, QUrl
from PySide6.QtNetwork import QLocalSocket
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from deckdrop.presentation.controller import Controller
from deckdrop.services.pairing import PairingInbox, socket_path


def main():
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Deck Drop")
    app.setOrganizationName("DeckDrop")
    lock = QLockFile(socket_path() + ".lock")
    if not lock.tryLock(0):
        existing = QLocalSocket()
        existing.connectToServer(socket_path())
        if existing.waitForConnected(1500):
            existing.write(b'{"activate":true}\n')
            existing.waitForBytesWritten(1500)
        return 0
    controller = Controller()
    inbox = PairingInbox(controller)
    inbox.listen()
    engine = QQmlApplicationEngine()
    engine.setInitialProperties({"backend": controller})
    engine.load(QUrl.fromLocalFile(str(Path(__file__).parent / "deckdrop/presentation/qml/Main.qml")))
    if not engine.rootObjects():
        return 1
    window = engine.rootObjects()[0]

    def activate():
        window.show()
        window.raise_()
        window.requestActivate()

    inbox.activate.connect(activate)
    result = app.exec()
    inbox.close()
    engine.deleteLater()
    QCoreApplication.sendPostedEvents(None, QEvent.DeferredDelete)
    return result


if __name__ == "__main__":
    sys.exit(main())
