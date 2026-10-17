<!--
  README.md
  DeckDrop

  Created by Andrii Bryzhnychenko on 10/17/26.
-->

# Deck Drop for Steam Deck

A small Desktop Mode receiver using Python 3.10+ and Qt Quick/QML. It keeps the Mac app’s dark panels, mint accents, and three-step layout.

## Start the receiver

Copy the `SteamDeck` folder onto your Deck. In Desktop Mode, open a terminal in that folder and run:

```sh
bash install.sh
```

The installer creates a local Python virtual environment, downloads Qt for Python, and adds **Deck Drop** to the application menu. Keep the receiver folder in place: the launcher points to it. Installation requires internet access, Python with `venv`, and pip. Later launches work offline and reuse the environment. It does not change SteamOS system files or require administrator access. If Python, venv, or pip is unavailable on your Deck, this source launcher will not work; a self-contained Linux/Flatpak package is not included yet.

Open **Deck Drop** from the application menu after installation. For a terminal launch without installing a menu entry, use `bash run.sh`.

For an existing Python environment:

```sh
python3 -m pip install -r requirements.txt
python3 main.py
```

## Pair and copy

1. Open Deck Drop on the Mac, choose the source folder, and select **Deck app**.
2. Click **Start sharing**, then **Copy pairing link**.
3. Transfer the complete link privately to the Deck, paste it into the receiver, and click **Connect**.
4. Click **Choose folder…** and select a folder on internal storage or your microSD. The location must already exist and be writable.
5. Click **Start copying**. Keep both devices awake and the Mac app open until completion.
6. Click **Stop sharing** on the Mac when finished. The link becomes invalid immediately.

No macOS account password or Windows File Sharing setup is used. Paste the link only into Deck Drop: it grants read access to the selected folder while the session is active. Pairing information is held in memory and is not saved between launches.

## Transfer behavior

- HTTPS with a fresh self-signed server certificate per sharing session. The receiver checks its SHA-256 fingerprint against the private invitation **before** sending the authorization key.
- A random 256-bit access key authorizes manifest and file requests. The key appears in the invitation fragment, not an HTTP URL path or query.
- Read-only source access; symlinks and special files are skipped. File downloads use server-assigned IDs, and the Mac opens paths without following symlinks.
- Files are streamed to disk, including empty files and empty folders. The receiver checks available space before copying.
- Existing destination folders are preserved; another copy gets a numbered name.
- An interrupted copy stays in an explicitly named `.incomplete-…` folder. A partial current file is removed; completed files remain. Automatic resume is not implemented.
- Cancellation is cooperative. A stalled network operation may take up to 15 seconds to time out. Closing the window during a transfer requests cancellation first; close again after it finishes.
- Copying creates regular files and folders. Symlinks, extended attributes, executable permissions, and macOS resource forks are not preserved. This is intended for data, mods, and saves, not a full filesystem backup.
- Do not change the source folder during a transfer. The file list and sizes are captured when sharing starts; this is not a filesystem snapshot.
- Up to 100,000 entries and a 16 MiB manifest are supported. IPv4 is used for invitations.

## Validation

Run the protocol tests without installing Qt:

```sh
python3 -m unittest discover -s tests -p test_protocol.py -v
```

The optional integration tests use the real Swift server. From the repository root on a Mac:

```sh
xcrun swiftc -swift-version 6 -parse-as-library DeckDrop/Transfer/*.swift Tests/Fixtures/TransferServerHarness.swift -o /tmp/deckdrop-server-harness
DECKDROP_SERVER_BINARY=/tmp/deckdrop-server-harness python3 -m unittest discover -s SteamDeck/tests -p test_protocol.py -v
```

For the QML/controller integration test, use the same server binary and a Python environment with the receiver’s requirements installed:

```sh
QT_QPA_PLATFORM=offscreen DECKDROP_SERVER_BINARY=/tmp/deckdrop-server-harness python3 -m unittest discover -s SteamDeck/tests -p test_frontend.py -v
```

On 2026-10-17, the receiver was installed on a Steam Deck running Python 3.13.5 and exercised on its live 1280×800 Desktop Mode display. The real Swift HTTPS server on the Mac sent a 33.6 MB test folder over Wi-Fi to both internal storage and microSD. SHA-256 hashes matched for every file, including a Unicode filename and an empty file; empty folders survived. Repeating the copy preserved the original destination and produced a numbered folder. The repeated copies took 22.44 seconds to internal storage and 23.93 seconds to microSD on that network; these are observations, not a throughput guarantee.

The live check drives the receiver’s QML pairing and copy buttons, sets the destination through its controller, and captures the completed window. It does not validate the native folder picker, touch/controller input, or Game Mode. Those remain unverified; Game Mode integration and Flatpak distribution are not included.

To repeat a live check with a running Mac sharing session, save its private pairing link to a local file on the Deck and run:

```sh
.venv/bin/python tests/live_transfer.py /path/to/private-invitation /path/to/destination --screenshot /tmp/deckdrop-complete.png
```

The check copies the shared folder and prints SHA-256 hashes for comparison with the source. It keeps received files. Its empty-folder check expects the generated verification fixture’s `empty folder` directory.
