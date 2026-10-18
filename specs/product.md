# Product specification

## Purpose and platforms

Copy a local Mac folder to Steam Deck internal storage or a mounted microSD while preserving existing destination folders. The Mac app supports macOS 14+ for SMB assistance and requires macOS 15+ for paired transfers. The receiver targets SteamOS Desktop Mode with Python 3.10+ and Qt for Python.

## Automatic transfer

1. The user chooses or drops exactly one readable local folder. Files, application bundles, multiple selections, and remote URLs are rejected.
2. A confirmation asks for the trusted SSH host and an existing writable Deck destination. Saving defaults is opt-in.
3. The Mac prepares a temporary sharing session and starts the SSH helper. The helper requires the receiver installation at `~/Applications/DeckDrop` and an active desktop for its progress display.
4. The Deck verifies the Mac certificate, downloads the manifest, and streams files to the chosen destination. Both apps display progress and estimated time remaining when available.
5. The Mac displays **Transferred** only after the helper confirms a completed destination. The Mac then stops sharing.

Acceptance criteria:

- A missing/unmounted microSD or invalid destination fails without choosing another drive.
- Existing copies survive; subsequent copies use numbered names such as `Games (2)`.
- Source selection cannot change during session startup or transfer.
- Stopping sharing cancels the SSH helper and revokes the current session. Stale task completions cannot replace a newer session's state.
- Secrets are not persisted, passed in process arguments, or copied to the clipboard automatically.
- Progress is visible before helper completion. Reaching 100% bytes alone is not a successful completion acknowledgement.

## Manual receiver flow

The user starts sharing on the Mac and either pairs automatically over trusted SSH or privately pastes a pairing link into the Deck app. Pairing succeeds after the Deck verifies the connection and loads the manifest. The user chooses an existing destination and starts copying. Manual sharing stays active until the user stops it. A busy receiver refuses a new pairing request.

## Failure and cancellation

Certificate mismatch, expired authorization, insufficient destination space, invalid paths, changed file sizes, and interrupted connections must produce an error rather than report success. Cancellation is cooperative; blocked network operations may wait for their timeout. Partial copies remain in a clearly named incomplete folder, with the current partial file removed. Completed files in that incomplete folder remain available.

## SMB assistance

The Mac app lets the user choose a source, inspect local addresses and sharing diagnostics, copy an SMB address, and open Sharing settings. The user configures macOS File Sharing and copies through Dolphin. A successful local port-445 probe confirms only a local listener; it does not establish authentication, share permissions, or Deck reachability.

## Limits

- No automatic device discovery, short numeric pairing codes, resume, synchronization, or cloud relay.
- No Game Mode or Flatpak distribution contract.
- Only regular files and directories are copied. Symlinks, special files, extended attributes, executable permissions, and resource forks are not preserved.
- The manifest is captured at session start; source contents are not a filesystem snapshot and must remain stable during transfer.
- The sender limits enumeration to 100,000 entries; the receiver limits manifests to 16 MiB.
- Invitations use IPv4. Both devices must stay awake; the Mac app must remain open for paired transfers.
