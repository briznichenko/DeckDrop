import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import time

os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from PySide6.QtCore import QCoreApplication, QEvent, QMetaObject, QObject, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
from PySide6.QtTest import QTest

from deckdrop.controller import Controller


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("invitation", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--screenshot", type=Path, required=True)
    args = parser.parse_args()
    app = QGuiApplication([])
    controller = Controller()
    engine = QQmlApplicationEngine()
    engine.setInitialProperties({"backend": controller})
    engine.load(QUrl.fromLocalFile(str(Path(__file__).resolve().parents[1] / "qml/Main.qml")))
    if not engine.rootObjects():
        raise RuntimeError("Receiver window did not load")
    window = engine.rootObjects()[0]
    if not isinstance(window, QQuickWindow):
        raise RuntimeError("Receiver did not create a Qt Quick window")

    def wait_until(predicate, timeout=120):
        deadline = time.monotonic() + timeout
        while not predicate() and time.monotonic() < deadline:
            QTest.qWait(20)
        if not predicate():
            raise RuntimeError(f"Receiver timed out: {controller.state}: {controller.message}")

    try:
        window.findChild(QObject, "pairingInput").setProperty("text", args.invitation.read_text())
        QMetaObject.invokeMethod(window.findChild(QObject, "connectButton"), "clicked")
        wait_until(lambda: not controller.busy)
        if not controller.paired:
            raise RuntimeError(controller.message)
        args.destination.mkdir(parents=True, exist_ok=True)
        controller.chooseDestination(QUrl.fromLocalFile(str(args.destination)))
        started = time.monotonic()
        QMetaObject.invokeMethod(window.findChild(QObject, "startCopyButton"), "clicked")
        wait_until(lambda: not controller.busy)
        elapsed = time.monotonic() - started
        if controller.state != "complete":
            raise RuntimeError(controller.message)
        QTest.qWait(300)
        if not window.grabWindow().save(str(args.screenshot)):
            raise RuntimeError("Could not save the receiver screenshot")
        result = Path(controller._result)
        hashes = {}
        for path in sorted(result.rglob("*")):
            if path.is_file():
                digest = hashlib.sha256()
                with path.open("rb") as source:
                    for chunk in iter(lambda: source.read(1024 * 1024), b""):
                        digest.update(chunk)
                hashes[str(path.relative_to(result))] = digest.hexdigest()
        print(json.dumps({"result": str(result), "seconds": round(elapsed, 2), "sha256": hashes,
                          "empty_folder": (result / "empty folder").is_dir()}, ensure_ascii=False))
    finally:
        if controller.busy:
            controller.cancel()
            wait_until(lambda: not controller.busy, timeout=20)
        engine.deleteLater()
        QCoreApplication.sendPostedEvents(None, QEvent.DeferredDelete)


if __name__ == "__main__":
    main()
