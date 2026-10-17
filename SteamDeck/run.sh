#!/bin/bash
#
#  run.sh
#  DeckDrop
#
#  Created by Andrii Bryzhnychenko on 10/17/26.
#
set -euo pipefail
receiver_dir="$(cd "$(dirname "$0")" && pwd)"
receiver_python="$receiver_dir/.venv/bin/python"
if [ ! -x "$receiver_python" ]; then
    python3 -m venv "$receiver_dir/.venv"
fi
if ! "$receiver_python" -c 'import PySide6.QtQuick' >/dev/null 2>&1; then
    "$receiver_python" -m pip install -r "$receiver_dir/requirements.txt"
fi
exec "$receiver_python" "$receiver_dir/main.py"
