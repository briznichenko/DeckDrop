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

from ..transfer.protocol import Cancelled, Client, Pairing
from ..transfer.progress import ProgressEstimate, remaining_text


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
    progressed = Signal(float, str, str, float)

    def __init__(self, invitation: str, destination: str = "", manifest: dict | None = None, parent=None):
        super().__init__(parent)
        self.invitation = invitation
        self.destination = destination
        self.manifest_data = manifest
        self.stop_event = threading.Event()
        self._last_progress = 0.0
        self.estimate = ProgressEstimate()

    def run(self):
        try:
            pairing = Pairing.parse(self.invitation)
            client = Client(pairing, self.stop_event)
            if self.manifest_data is None:
                self.inspected.emit(pairing, client.manifest())
            else:
                self.estimate = ProgressEstimate()
                self.progress(0, sum(file["size"] for file in self.manifest_data["files"]), "")
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
        remaining = self.estimate.remaining(completed, total)
        self.progressed.emit(completed / total if total else 1.0, f"{format_bytes(completed)} / {format_bytes(total)}", current, remaining if remaining is not None else -1)


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
        self._remaining_text = "Estimating…"
        self._current_file = ""
        self._result = ""
        self._invitation = ""
        self._manifest = None
        self._worker = None
        self._busy = False
        self.external_cancel_requested = False
        self._external_transfer = False

    externalTransfer = Property(bool, lambda self: self._external_transfer, notify=changed)
    state = Property(str, lambda self: self._state, notify=changed)
    message = Property(str, lambda self: self._message, notify=changed)
    folderName = Property(str, lambda self: self._folder_name, notify=changed)
    folderDetail = Property(str, lambda self: self._folder_detail, notify=changed)
    destination = Property(str, lambda self: self._destination, notify=changed)
    progress = Property(float, lambda self: self._progress, notify=changed)
    progressText = Property(str, lambda self: self._progress_text, notify=changed)
    remainingText = Property(str, lambda self: self._remaining_text, notify=changed)
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
        self._external_transfer = False
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
        if self._busy or self._external_transfer or self._manifest is None or not self._destination:
            return
        self._progress = 0.0
        self._progress_text = "Preparing your folder…"
        self._remaining_text = "Estimating…"
        self._current_file = ""
        self._message = "Keep both devices awake until copying finishes."
        self._state = "copying"
        self.launch(Worker(self._invitation, self._destination, self._manifest, self))

    @Slot(float, str, str, float)
    def progressed(self, progress, text, current, remaining=-1):
        self._progress, self._progress_text, self._current_file = progress, text, current
        self._remaining_text = remaining_text(remaining if remaining >= 0 else None)
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
        if self._busy and self._worker is None:
            self.external_cancel_requested = True
            self._message = "Cancelling…"
            self.changed.emit()
        if self._worker:
            self._worker.stop_event.set()
            self._message = "Cancelling… a stalled connection may take up to 15 seconds to close."
            self.changed.emit()

    def beginExternalTransfer(self, name, count, total, destination):
        self._external_transfer = True
        self._invitation = ""
        self._manifest = {"name": name, "files": []}
        self._folder_name = name
        self._folder_detail = f"{count} files · {format_bytes(total)}"
        self._destination = destination
        self._progress = 0.0
        self._progress_text = f"0 B / {format_bytes(total)}"
        self._current_file = ""
        self._remaining_text = "Estimating…"
        self._result = ""
        self._state = "copying"
        self._message = "Mac connected · Transfer started on Mac"
        self._busy = True
        self.external_cancel_requested = False
        self.changed.emit()

    def endExternalTransfer(self, path=None, error=None):
        self._busy = False
        if path:
            self.copied(path)
        elif self.external_cancel_requested or error is None:
            self.cancelled("Transfer cancelled on the Deck." if self.external_cancel_requested
                           else "Mac disconnected · Transfer cancelled")
        else:
            self.failed(error)

    @Slot()
    def disconnectMac(self):
        if self._busy:
            return
        self._external_transfer = False
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
