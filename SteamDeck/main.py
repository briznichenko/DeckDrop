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

from PySide6.QtCore import QCoreApplication, QEvent, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from deckdrop.controller import Controller


def main():
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Deck Drop")
    app.setOrganizationName("DeckDrop")
    controller = Controller()
    engine = QQmlApplicationEngine()
    engine.setInitialProperties({"backend": controller})
    engine.load(QUrl.fromLocalFile(str(Path(__file__).parent / "qml/Main.qml")))
    if not engine.rootObjects():
        return 1
    result = app.exec()
    engine.deleteLater()
    QCoreApplication.sendPostedEvents(None, QEvent.DeferredDelete)
    return result


if __name__ == "__main__":
    sys.exit(main())
