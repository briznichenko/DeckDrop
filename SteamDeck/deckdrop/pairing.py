import json
import os
from pathlib import Path

from PySide6.QtCore import QObject, QStandardPaths, QTimer, Signal
from PySide6.QtNetwork import QLocalServer

from .protocol import Pairing, TransferError


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
            if request.get("activate") is True:
                self.activate.emit()
                self.reply(client, {"paired": False})
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
        if self.pending is client:
            self.pending = None
        self.clients.pop(client, None)
        client.deleteLater()

    def close(self):
        for client in list(self.clients):
            client.abort()
        self.server.close()
