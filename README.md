<!--
  README.md
  DeckDrop

  Created by Andrii Bryzhnychenko on 10/17/26.
-->

# Deck Drop

A native macOS setup assistant for copying folders from a Mac to a Steam Deck over SMB. Requires macOS 14 or later. The included app is built for Apple Silicon.

## Use

1. Open Deck Drop.app and choose your source folder.
2. Click Open Sharing Settings. Enable File Sharing and add that folder to Shared Folders. Under Options, enable SMB and your Mac account. Read-only access is enough for the Deck to copy files from the Mac.
3. Return to Deck Drop and click Refresh. The status checks whether this Mac accepts a local TCP connection on SMB port 445. It does not test authentication, folder permissions, or reachability from the Deck.
4. On the same local network, put the Deck in Desktop Mode. In Dolphin, press Ctrl+L and type the displayed smb:// address.
5. Sign in with your Mac account username and password. Open the shared folder and copy it to your microSD, shown in Dolphin's sidebar.

Keep both devices awake until copying finishes. Deck Drop can be closed during the transfer: macOS serves the files, and Dolphin copies them. Remove the share or disable File Sharing afterward if you no longer need it.

## What the app does

- Selects a folder and opens it in Finder.
- Lists active Wi-Fi/Ethernet/bridge IPv4 addresses, with a selector when there are several.
- Copies the Mac's SMB server address or the selected folder path.
- Opens the macOS Sharing settings and gives the corresponding setup steps.
- Checks for a local SMB listener and displays the system's share listing under Details.
- Refreshes on activation or on request.

Choosing a folder does not share it automatically. The app does not configure SMB, store credentials, mount the Deck, or copy files itself. Sharing remains controlled by macOS. IPv6-only networks are not supported by the address display. A read-only setup assistant avoids installing a privileged helper for a one-time setup.

## Build

Open `DeckDrop.xcodeproj` in Xcode, select the shared **DeckDrop** scheme and **My Mac**, then press **⌘R**. Debug and Release configurations use Swift 6 and local ad-hoc signing, so a development team is not required for running on your Mac. The project includes all Swift source files, the app icon, and Info.plist. SMB probes require the app to run without App Sandbox.

The Swift package and packaging script are also available:

Install Xcode or its command-line tools with Swift 6 or newer, then run:

```sh
bash build.sh
```

This builds a release executable, wraps it in an app bundle in the parent outputs folder, and signs it locally with an ad-hoc signature. No third-party packages are used. The signature is suitable for local use; public distribution would require Developer ID signing and notarization.

The interface uses SwiftUI and Observation. UI state lives in a MainActor-isolated model; blocking system probes run in a separate actor. Cancellation is checked before a completed probe updates the UI. Already-running system commands are allowed to finish; the network probe has a two-second connection timeout.

## Troubleshooting

- No address: connect the Mac to Wi-Fi/Ethernet and refresh.
- Several addresses: select the interface on the same network as the Deck.
- SMB not detected: enable File Sharing and SMB in System Settings, then refresh. A failed local probe can also reflect local restrictions.
- Deck cannot connect: check that the devices are on the same LAN, neither is on an isolated guest network, and macOS firewall settings permit File Sharing.
- Login rejected: use the Mac account password, not a Steam password or Apple Account password; enable that account for SMB in Options.
- Folder absent: add it to Shared Folders and check that account's access permissions.

## References

- [Apple: Set up file sharing](https://support.apple.com/guide/mac-help/set-up-file-sharing-on-mac-mh17131/mac)
- [Apple: Set up SMB file sharing](https://support.apple.com/guide/mac-help/set-up-smb-file-sharing-on-mac-mh14107/mac)
- [KDE: Network folders in Dolphin](https://docs.kde.org/trunk_kf6/en/plasma-desktop/knetattach/using-knetattach.html)

## Source layout

- `DeckDropApp.swift`: app entry point and window configuration.
- `TransferModel.swift`: observable UI state and user actions.
- `SystemProbe.swift`: system commands and local network discovery.
- `NetworkAddress.swift` and `SystemSnapshot.swift`: values returned by the probe.
- `Views/`: main screen, sidebar, setup cards, and diagnostics.
- `Views/Components/`: shared card and instruction views.
