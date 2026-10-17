#!/bin/bash
set -euo pipefail
receiver_dir="$(cd "$(dirname "$0")" && pwd)"
python3 -m venv "$receiver_dir/.venv"
"$receiver_dir/.venv/bin/python" -m pip install -r "$receiver_dir/requirements.txt"
"$receiver_dir/.venv/bin/python" - "$receiver_dir" <<'PY'
import os
from pathlib import Path
import sys

root = Path(sys.argv[1])
applications = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "applications"
applications.mkdir(parents=True, exist_ok=True)

def quote(value):
    escaped = str(value).replace("%", "%%")
    for character in ('\\', '"', '`', '$'):
        escaped = escaped.replace(character, '\\' + character)
    return '"' + escaped + '"'

launcher = applications / "local.deckdrop.receiver.desktop"
launcher.write_text(
    "[Desktop Entry]\nType=Application\nName=Deck Drop\n"
    "Comment=Receive folders from your Mac over your local network\n"
    f"Exec={quote(root / '.venv/bin/python')} {quote(root / 'main.py')}\n"
    "Icon=folder-download\nTerminal=false\nCategories=Network;FileTransfer;\n"
    "StartupNotify=true\n", encoding="utf-8"
)
print(f"Installed launcher: {launcher}")
print("Open Deck Drop from the application menu. Keep this receiver folder in place.")
PY
