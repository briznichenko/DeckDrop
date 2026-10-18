import ipaddress
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time

from deckdrop.transfer.protocol import Cancelled, Client, Pairing, TransferError
from deckdrop.transfer.progress import ProgressEstimate


def desktop_environment():
    environment = os.environ.copy()
    keys = {"DISPLAY", "WAYLAND_DISPLAY", "XAUTHORITY", "XDG_RUNTIME_DIR", "DBUS_SESSION_BUS_ADDRESS", "XDG_SESSION_TYPE"}
    for process in Path("/proc").iterdir():
        try:
            if not process.name.isdigit() or process.stat().st_uid != os.getuid():
                continue
            if (process / "comm").read_text().strip() != "plasmashell":
                continue
            for item in (process / "environ").read_bytes().split(b"\0"):
                key, _, value = item.partition(b"=")
                if key.decode(errors="replace") in keys:
                    environment[key.decode()] = value.decode()
            return environment
        except (OSError, UnicodeError):
            continue
    raise TransferError("Switch the Deck to Desktop Mode, then retry automatic pairing.")


def exchange(path, payload):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(20)
        client.connect(str(path))
        client.sendall(payload)
        data = bytearray()
        while b"\n" not in data:
            chunk = client.recv(4096)
            if not chunk or len(data) + len(chunk) > 8192:
                raise TransferError("The receiver did not confirm pairing.")
            data.extend(chunk)
        return json.loads(bytes(data).split(b"\n", 1)[0])


def pair(request, progress=None):
    if not isinstance(request, dict):
        raise TransferError("Invalid pairing request.")
    invitation = request.get("invitation")
    if not isinstance(invitation, str):
        raise TransferError("Invalid pairing request.")
    pairing = Pairing.parse(invitation)
    connection = os.environ.get("SSH_CONNECTION", "").split()
    if len(connection) != 4:
        raise TransferError("Automatic pairing must be started through SSH from the Mac.")
    action = request.get("action", "pair")
    transport = request.get("transport", "direct")
    if transport not in ("direct", "ssh-tunnel"):
        raise TransferError("Unknown transfer transport.")
    host = "127.0.0.1" if action == "transfer" and transport == "ssh-tunnel" else str(ipaddress.IPv4Address(connection[0]))
    invitation = f"deckdrop://{host}:{pairing.port}/#{pairing.token}.{pairing.fingerprint}"
    if action == "transfer":
        destination = request.get("destination")
        if not isinstance(destination, str) or not destination.strip():
            raise TransferError("Choose a destination on the Deck first.")
        destination = Path(destination).expanduser()
        if not destination.is_absolute():
            raise TransferError("Use an absolute Deck destination path or ~/folder.")
        try:
            destination = destination.resolve(strict=True)
        except OSError:
            raise TransferError("The Deck destination is unavailable. Check that your microSD is mounted.") from None
        if not destination.is_dir() or not os.access(destination, os.W_OK):
            raise TransferError("The Deck destination must be a writable folder.")
        client = Client(Pairing.parse(invitation))
        manifest = client.manifest()
        display = TransferDisplay()
        try:
            display.start(manifest, destination)
            estimate = ProgressEstimate()
            last_progress = 0.0

            def report(completed, total, current):
                nonlocal last_progress
                now = time.monotonic()
                if completed < total and now - last_progress < 0.1:
                    return
                last_progress = now
                remaining = estimate.remaining(completed, total)
                display.progress(completed, total, current, remaining)
                if progress:
                    progress(completed, total, current, remaining)

            report(0, sum(file["size"] for file in manifest["files"]), "")
            final = client.download(manifest, destination, report)
            display.complete(final)
            return {"paired": True, "completed": True, "path": str(final)}
        except BaseException as error:
            display.fail(str(error))
            raise
        finally:
            display.close()
    if action != "pair":
        raise TransferError("Unknown Deck Drop action.")
    payload = json.dumps({"invitation": invitation}).encode() + b"\n"
    return receiver_exchange(payload)


def receiver_exchange(payload):
    environment = desktop_environment()
    path = Path(environment.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "deckdrop-receiver.sock"
    try:
        return exchange(path, payload)
    except (FileNotFoundError, ConnectionRefusedError):
        root = Path(__file__).resolve().parent
        python = root / ".venv/bin/python"
        if not python.is_file():
            raise TransferError("Install the Deck receiver with bash install.sh, then retry.") from None
        display_keys = ("DISPLAY", "WAYLAND_DISPLAY", "XAUTHORITY", "XDG_RUNTIME_DIR", "DBUS_SESSION_BUS_ADDRESS", "XDG_SESSION_TYPE")
        command = ["systemd-run", "--user", "--collect", "--quiet", "--unit=deckdrop-receiver"]
        command.extend(f"--setenv={key}={environment[key]}" for key in display_keys if key in environment)
        command.extend([str(python), str(root / "main.py")])
        subprocess.run(command, env=environment, stdin=subprocess.DEVNULL,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            try:
                return exchange(path, payload)
            except (FileNotFoundError, ConnectionRefusedError):
                time.sleep(.1)
        raise TransferError("Deck Drop could not open. Launch it from the Deck application menu and retry.")


class TransferDisplay:
    def __init__(self):
        environment = desktop_environment()
        path = Path(environment.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "deckdrop-receiver.sock"
        self.client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.client.settimeout(20)
        try:
            self.client.connect(str(path))
        except (FileNotFoundError, ConnectionRefusedError):
            receiver_exchange(b'{"activate":true}\n')
            self.client.connect(str(path))
        self.reader = self.client.makefile("rb")

    def send(self, event, **fields):
        self.client.sendall(json.dumps({"action": "transfer-status", "event": event, **fields}).encode() + b"\n")
        data = self.reader.readline(8193)
        if len(data) > 8192 or not data.endswith(b"\n"):
            raise TransferError("The Deck app disconnected. Retry the transfer.")
        reply = json.loads(data)
        if not reply.get("accepted"):
            if "accepted" not in reply:
                raise TransferError("Reopen Deck Drop on the Deck to load its connection and progress update.")
            raise TransferError(reply.get("error", "The Deck app could not display this transfer."))
        if reply.get("cancelled"):
            raise Cancelled("Transfer cancelled on the Deck.")

    def start(self, manifest, destination):
        self.send("start", name=manifest["name"], count=len(manifest["files"]),
                  totalBytes=sum(file["size"] for file in manifest["files"]), destination=str(destination))

    def progress(self, completed, total, current, remaining):
        self.send("progress", completedBytes=completed, totalBytes=total, currentFile=current, remainingSeconds=remaining)

    def complete(self, path):
        self.send("complete", path=str(path))

    def fail(self, error):
        try:
            self.send("error", error=error)
        except (OSError, ValueError, TransferError):
            pass

    def close(self):
        self.reader.close()
        self.client.close()


def main():
    try:
        data = sys.stdin.buffer.readline(4097)
        if len(data) > 4096 or not data.endswith(b"\n"):
            raise TransferError("Invalid pairing request.")
        def report_progress(completed, total, current, remaining):
            print(json.dumps({"type": "progress", "completedBytes": completed,
                              "totalBytes": total, "currentFile": current, "remainingSeconds": remaining}), flush=True)

        result = pair(json.loads(data), report_progress)
    except (TransferError, ValueError, OSError, subprocess.TimeoutExpired) as error:
        result = {"paired": False, "error": str(error) if isinstance(error, TransferError) else "Could not complete the connection. Check SSH and the destination, then retry."}
    print(json.dumps(result), flush=True)


if __name__ == "__main__":
    main()
