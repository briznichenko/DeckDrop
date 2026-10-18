# Verification

Run commands from the repository root unless noted otherwise. The reorganization changes file locations and imports; it does not replace the existing harnesses with a new test framework.

## Build the Mac application

```sh
xcodebuild -project DeckDrop.xcodeproj -scheme DeckDrop -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/deckdrop-xcode-build build
bash Scripts/build-macos.sh
```

The packaging script uses SwiftPM and creates `dist/Deck Drop.app` with local ad-hoc signing. Resources are excluded from SwiftPM source compilation and copied into the app bundle by the packaging script.

## Local automated checks

```sh
bash Scripts/test-local.sh
```

The script compiles the Swift HTTPS server harness, runs folder-selection/defaults checks and SSH message/progress/cancellation checks, then runs the receiver suite against that real server. It does not contact a Deck or install dependencies. Without Qt, GUI/pairing/automatic-transfer tests are explicitly skipped.

Select a Python environment containing `SteamDeck/requirements.txt` to include Qt checks:

```sh
DECKDROP_PYTHON=/path/to/venv/bin/python bash Scripts/test-local.sh
```

For protocol and progress unit checks without Qt or a Swift server:

```sh
python3 -m unittest discover -s SteamDeck/tests -p test_protocol.py -v
python3 -m unittest discover -s SteamDeck/tests -p test_progress.py -v
```

The server-dependent tests in the first command are skipped when `DECKDROP_SERVER_BINARY` is absent. The full local script supplies that binary.

## Manual and live checks

The `QuickTransferHarness` and `SSHPairingHarness` require explicit arguments and may contact a device. They are not run by the local script. On a configured Deck, `SteamDeck/tests/live_transfer.py` exercises the actual QML transfer flow and records destination hashes; it keeps copied files.

Before claiming a live transfer works, check the installed receiver, trusted non-interactive SSH, internal and mounted-card destinations, repeated-copy preservation, cancellation, and source/destination hashes. Local tests do not establish Wi-Fi/firewall behavior, card availability, or deployed receiver compatibility.

Before claiming visual completion, capture and inspect the sizes and states described in [UI](ui.md). Touch input, native folder pickers, and Game Mode require their own checks.

## Repository hygiene

```sh
git diff --check
git check-ignore AGENTS.md .local/ai/AGENTS.md .local/ai/rules/ui-parity.mdc
```

Keep AI instructions, prompts, generated reports, screenshots, and scratch logs under ignored `.local/`. Specs and repeatable build/test scripts remain tracked. Ignore patterns also cover conventional AI-tool configuration paths; adding an ignore pattern does not remove a file that was already tracked.

## Latest local verification — 2026-10-17

After reorganizing the folders, the Xcode Debug build and SwiftPM release packaging passed. Both executable Swift checks passed, and all 23 receiver tests passed with Qt and the real local Swift HTTPS server. Every Xcode source reference resolved. No live Deck deployment or new device/UI validation was performed for this file reorganization.
