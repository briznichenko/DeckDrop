#
#  controller.py
#  DeckDrop
#
#  Created by Andrii Bryzhnychenko on 10/17/26.
#

from __future__ import annotations

from pathlib import Path
import threading
import time

from PySide6.QtCore import QObject, Property, QThread, QUrl, Signal, Slot
from PySide6.QtGui import QDesktopServices, QGuiApplication

from .protocol import Cancelled, Client, Pairing


def format_bytes(value: int) -> str:
    number = float(value)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if number < 1000 or unit == "TB":
            return f"{number:.1f} {unit}" if unit != "B" else f"{int(number)} B"
        number /= 1000


class Worker(QThread):
    inspected = Signal(object, object)
    copied = Signal(str)
    failed = Signal(str)
    cancelled = Signal(str)
    progressed = Signal(float, str, str)

    def __init__(self, invitation: str, destination: str = "", manifest: dict | None = None, parent=None):
        super().__init__(parent)
        self.invitation = invitation
        self.destination = destination
        self.manifest_data = manifest
        self.stop_event = threading.Event()
        self._last_progress = 0.0

    def run(self):
        try:
            pairing = Pairing.parse(self.invitation)
            client = Client(pairing, self.stop_event)
            if self.manifest_data is None:
                self.inspected.emit(pairing, client.manifest())
            else:
                final = client.download(self.manifest_data, Path(self.destination), self.progress)
                self.copied.emit(str(final))
        except Cancelled as error:
            self.cancelled.emit(str(error))
        except Exception as error:
            message = str(error)
            if isinstance(error, (ConnectionError, TimeoutError, OSError)):
                message = "Could not reach your Mac. Keep Deck Drop open, use the same local network, and allow its incoming connection in the Mac firewall."
            self.failed.emit(message)

    def progress(self, completed: int, total: int, current: str):
        now = time.monotonic()
        if completed < total and now - self._last_progress < 0.1:
            return
        self._last_progress = now
        self.progressed.emit(completed / total if total else 1.0, f"{format_bytes(completed)} / {format_bytes(total)}", current)


class Controller(QObject):
    changed = Signal()

    def __init__(self):
        super().__init__()
        self._state = "unpaired"
        self._message = ""
        self._folder_name = ""
        self._folder_detail = ""
        self._destination = ""
        self._progress = 0.0
        self._progress_text = ""
        self._current_file = ""
        self._result = ""
        self._invitation = ""
        self._manifest = None
        self._worker = None
        self._busy = False

    state = Property(str, lambda self: self._state, notify=changed)
    message = Property(str, lambda self: self._message, notify=changed)
    folderName = Property(str, lambda self: self._folder_name, notify=changed)
    folderDetail = Property(str, lambda self: self._folder_detail, notify=changed)
    destination = Property(str, lambda self: self._destination, notify=changed)
    progress = Property(float, lambda self: self._progress, notify=changed)
    progressText = Property(str, lambda self: self._progress_text, notify=changed)
    currentFile = Property(str, lambda self: self._current_file, notify=changed)
    busy = Property(bool, lambda self: self._busy, notify=changed)
    paired = Property(bool, lambda self: self._manifest is not None, notify=changed)

    def launch(self, worker: Worker):
        self._worker = worker
        self._busy = True
        worker.inspected.connect(self.inspected)
        worker.copied.connect(self.copied)
        worker.failed.connect(self.failed)
        worker.cancelled.connect(self.cancelled)
        worker.progressed.connect(self.progressed)
        worker.finished.connect(self.worker_finished)
        worker.finished.connect(worker.deleteLater)
        self.changed.emit()
        worker.start()

    @Slot(str)
    def connectMac(self, invitation: str):
        if self._busy:
            return
        self._manifest = None
        self._folder_name = ""
        self._folder_detail = ""
        self._result = ""
        self._invitation = invitation.strip()
        self._message = "Verifying your Mac’s encrypted connection…"
        self._state = "connecting"
        self.launch(Worker(self._invitation, parent=self))

    @Slot(object, object)
    def inspected(self, pairing, manifest):
        self._manifest = manifest
        self._folder_name = manifest["name"]
        self._folder_detail = f"{len(manifest['files'])} files · {format_bytes(sum(f['size'] for f in manifest['files']))}"
        self._message = "Mac verified. Choose where to save your folder."
        self._state = "ready"
        self.changed.emit()

    @Slot(QUrl)
    def chooseDestination(self, url):
        if self._busy:
            return
        self._destination = url.toLocalFile()
        self.changed.emit()

    @Slot()
    def startCopy(self):
        if self._busy or self._manifest is None or not self._destination:
            return
        self._progress = 0.0
        self._progress_text = "Preparing your folder…"
        self._current_file = ""
        self._message = "Keep both devices awake until copying finishes."
        self._state = "copying"
        self.launch(Worker(self._invitation, self._destination, self._manifest, self))

    @Slot(float, str, str)
    def progressed(self, progress, text, current):
        self._progress, self._progress_text, self._current_file = progress, text, current
        self.changed.emit()

    @Slot(str)
    def copied(self, path):
        self._result = path
        self._progress = 1.0
        self._state = "complete"
        self._message = "All yours. You can stop sharing on the Mac."
        self.changed.emit()

    @Slot(str)
    def failed(self, message):
        self._state = "error"
        self._message = message
        self.changed.emit()

    @Slot(str)
    def cancelled(self, message):
        self._state = "cancelled"
        self._message = message
        self.changed.emit()

    @Slot()
    def worker_finished(self):
        self._worker = None
        self._busy = False
        self.changed.emit()

    @Slot()
    def cancel(self):
        if self._worker:
            self._worker.stop_event.set()
            self._message = "Cancelling… a stalled connection may take up to 15 seconds to close."
            self.changed.emit()

    @Slot()
    def disconnectMac(self):
        if self._busy:
            return
        self._manifest = None
        self._invitation = ""
        self._folder_name = ""
        self._folder_detail = ""
        self._state = "unpaired"
        self._message = ""
        self.changed.emit()

    @Slot(result=str)
    def clipboardText(self):
        return QGuiApplication.clipboard().text()

    @Slot()
    def openResult(self):
        if self._result:
            QDesktopServices.openUrl(QUrl.fromLocalFile(self._result))
