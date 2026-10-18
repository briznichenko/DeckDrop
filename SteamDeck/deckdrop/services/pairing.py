import json
import math
import os
from pathlib import Path

from PySide6.QtCore import QObject, QStandardPaths, QTimer, Signal
from PySide6.QtNetwork import QLocalServer

from ..transfer.protocol import Pairing, TransferError


def socket_path():
    runtime = QStandardPaths.writableLocation(QStandardPaths.RuntimeLocation)
    return str(Path(runtime) / "deckdrop-receiver.sock")


class PairingInbox(QObject):
    activate = Signal()

    def __init__(self, controller, path=None):
        super().__init__()
        self.controller = controller
        self.path = path or socket_path()
        self.server = QLocalServer(self)
        self.server.setSocketOptions(QLocalServer.UserAccessOption)
        self.server.newConnection.connect(self.accept)
        self.pending = None
        self.clients = {}
        self.external = None
        self.timers = {}
        controller.changed.connect(self.completed)

    def listen(self):
        QLocalServer.removeServer(self.path)
        if not self.server.listen(self.path):
            raise RuntimeError("Could not open the local pairing endpoint")
        os.chmod(self.path, 0o600)

    def accept(self):
        while self.server.hasPendingConnections():
            client = self.server.nextPendingConnection()
            if len(self.clients) >= 4:
                client.abort()
                client.deleteLater()
                continue
            timer = QTimer(client)
            timer.setSingleShot(True)
            timer.timeout.connect(lambda client=client: client.abort())
            timer.start(25000)
            self.clients[client] = bytearray()
            self.timers[client] = timer
            client.readyRead.connect(lambda client=client: self.read(client))
            client.disconnected.connect(lambda client=client: self.disconnected(client))

    def read(self, client):
        if self.pending is client:
            return
        data = self.clients.get(client)
        if data is None:
            return
        data.extend(bytes(client.readAll()))
        if len(data) > 4096:
            self.reply(client, {"paired": False, "error": "Pairing request is too large."})
            return
        if b"\n" not in data:
            return
        try:
            request = json.loads(bytes(data).split(b"\n", 1)[0])
            if not isinstance(request, dict):
                raise ValueError
            if request.get("status") is True:
                self.reply(client, {"state": self.controller.state, "busy": self.controller.busy,
                                    "externalTransfer": self.controller.externalTransfer,
                                    "progress": self.controller.progress,
                                    "remainingText": self.controller.remainingText,
                                    "folderName": self.controller.folderName})
                return
            if request.get("activate") is True:
                self.activate.emit()
                self.reply(client, {"paired": False})
                return
            if request.get("action") == "transfer-status":
                self.clients[client].clear()
                self.transfer_status(client, request)
                return
            invitation = request.get("invitation")
            if not isinstance(invitation, str):
                raise ValueError
            Pairing.parse(invitation)
            if self.pending is not None or self.controller.busy:
                self.reply(client, {"paired": False, "error": "Deck Drop is busy. Finish or cancel the current operation on the Deck, then retry."})
                return
            self.pending = client
            self.activate.emit()
            self.controller.connectMac(invitation)
        except (ValueError, TypeError, TransferError):
            self.reply(client, {"paired": False, "error": "Invalid pairing request."})

    def transfer_status(self, client, request):
        event = request.get("event")
        if event == "start":
            if self.external is not None or self.pending is not None or self.controller.busy:
                self.reply(client, {"accepted": False, "error": "Deck Drop is busy."})
                return
            name, destination = request.get("name"), request.get("destination")
            count, total = request.get("count"), request.get("totalBytes")
            if not isinstance(name, str) or not isinstance(destination, str) or not destination.startswith("/"):
                raise ValueError
            if not isinstance(count, int) or not isinstance(total, int) or min(count, total) < 0:
                raise ValueError
            self.external = client
            self.timers[client].stop()
            self.controller.beginExternalTransfer(name, count, total, destination)
            self.activate.emit()
        elif self.external is not client:
            self.reply(client, {"accepted": False, "error": "No active Mac transfer."})
            return
        elif event == "progress":
            completed, total = request.get("completedBytes"), request.get("totalBytes")
            current, remaining = request.get("currentFile"), request.get("remainingSeconds")
            if not isinstance(completed, int) or not isinstance(total, int) or not 0 <= completed <= total:
                raise ValueError
            if not isinstance(current, str):
                raise ValueError
            if remaining is not None and (not isinstance(remaining, (int, float)) or not math.isfinite(remaining) or remaining < 0):
                raise ValueError
            from ..presentation.controller import format_bytes
            self.controller.progressed(completed / total if total else 1.0,
                                       f"{format_bytes(completed)} / {format_bytes(total)}", current,
                                       remaining if remaining is not None else -1)
        elif event in ("complete", "error"):
            path, error = request.get("path"), request.get("error")
            if event == "complete" and (not isinstance(path, str) or not path.startswith("/")):
                raise ValueError
            self.external = None
            self.controller.endExternalTransfer(path=path if event == "complete" else None,
                                                error=str(error) if error else None)
            self.reply(client, {"accepted": True})
            return
        else:
            raise ValueError
        client.write(json.dumps({"accepted": True, "cancelled": self.controller.external_cancel_requested}).encode() + b"\n")
        client.flush()

    def completed(self):
        if self.pending is None or self.controller.busy:
            return
        client, self.pending = self.pending, None
        paired = self.controller.paired and self.controller.state == "ready"
        self.reply(client, {"paired": paired, "error": None if paired else self.controller.message})

    def reply(self, client, value):
        client.write(json.dumps(value).encode() + b"\n")
        client.disconnectFromServer()

    def disconnected(self, client):
        if self.external is client:
            self.external = None
            self.controller.endExternalTransfer()
        self.timers.pop(client, None)
        if self.pending is client:
            self.pending = None
        self.clients.pop(client, None)
        client.deleteLater()

    def close(self):
        for client in list(self.clients):
            client.abort()
        self.server.close()
