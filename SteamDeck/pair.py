import ipaddress
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time

from deckdrop.protocol import Pairing, TransferError


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


def pair(request):
    if not isinstance(request, dict):
        raise TransferError("Invalid pairing request.")
    invitation = request.get("invitation")
    if not isinstance(invitation, str):
        raise TransferError("Invalid pairing request.")
    pairing = Pairing.parse(invitation)
    connection = os.environ.get("SSH_CONNECTION", "").split()
    if len(connection) != 4:
        raise TransferError("Automatic pairing must be started through SSH from the Mac.")
    host = str(ipaddress.IPv4Address(connection[0]))
    invitation = f"deckdrop://{host}:{pairing.port}/#{pairing.token}.{pairing.fingerprint}"
    payload = json.dumps({"invitation": invitation}).encode() + b"\n"
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


def main():
    try:
        data = sys.stdin.buffer.readline(4097)
        if len(data) > 4096 or not data.endswith(b"\n"):
            raise TransferError("Invalid pairing request.")
        result = pair(json.loads(data))
    except (TransferError, ValueError, OSError, subprocess.TimeoutExpired) as error:
        result = {"paired": False, "error": str(error) if isinstance(error, TransferError) else "Could not contact the Deck receiver. Keep the Deck in Desktop Mode and retry."}
    print(json.dumps(result))


if __name__ == "__main__":
    main()
