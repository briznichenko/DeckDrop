#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
check_dir="$(mktemp -d "${TMPDIR:-/tmp}/deckdrop-checks.XXXXXX")"
trap 'rm -rf "$check_dir"' EXIT
receiver_python="${DECKDROP_PYTHON:-python3}"
cd "$project_dir"
export CLANG_MODULE_CACHE_PATH="$check_dir/module-cache"
export SWIFT_MODULECACHE_PATH="$check_dir/module-cache"
transfer_sources=(DeckDrop/Models/TransferManifest.swift DeckDrop/Services/Transfer/*.swift)
model_sources=(DeckDrop/Models/*.swift DeckDrop/Services/System/*.swift DeckDrop/Services/Transfer/*.swift DeckDrop/ViewModels/*.swift)
xcrun swiftc -swift-version 6 -parse-as-library "${transfer_sources[@]}" Tests/MacOS/Harnesses/TransferServerHarness.swift -o "$check_dir/server"
xcrun swiftc -swift-version 6 -parse-as-library "${model_sources[@]}" Tests/MacOS/Harnesses/FolderSelectionHarness.swift -o "$check_dir/folder-selection"
"$check_dir/folder-selection"
xcrun swiftc -swift-version 6 -parse-as-library DeckDrop/Models/TransferManifest.swift DeckDrop/Services/Transfer/SSHPairing.swift Tests/MacOS/Harnesses/SSHTransferHarness.swift -o "$check_dir/ssh-transfer"
"$check_dir/ssh-transfer" "$project_dir/Tests/MacOS/Fixtures/ssh-stall.sh"
QT_QPA_PLATFORM=offscreen DECKDROP_SERVER_BINARY="$check_dir/server" "$receiver_python" -m unittest discover -s SteamDeck/tests -p 'test_*.py' -v
