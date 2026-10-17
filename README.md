<!--
  README.md
  DeckDrop

  Created by Andrii Bryzhnychenko on 10/17/26.
-->

# Deck Drop

A native macOS folder sender with a matching Steam Deck receiver. Paired transfers require macOS 15+; the original SMB setup assistant remains available on macOS 14+.

The receiver is installed on the configured Steam Deck at `/home/deck/Applications/DeckDrop`, with a **Deck Drop** application-menu entry. A locally built Mac app is available in `dist/Deck Drop.app`. On 2026-10-17, live encrypted copies to both the Deck’s internal storage and microSD passed SHA-256 verification. See the receiver’s validation section for the tested scope and remaining limits.

## Pair with the Deck app

1. Keep the Steam Deck awake in Desktop Mode, with the [receiver installed](SteamDeck/README.md).
2. On the Mac, choose a folder and select **Deck app**.
3. Click **Start sharing**, then **Pair automatically**. The default SSH host is `steamdeck`; you can enter another existing SSH alias or `deck@address`.
4. Deck Drop opens on the Deck and verifies the Mac. Choose an internal-storage or microSD destination and click **Start copying**.
5. Keep the Mac app open until copying finishes, then click **Stop sharing** to revoke access.

Automatic pairing uses your existing SSH configuration, keys, and known-host entries. It requires non-interactive key authentication and an already trusted Deck host; it never accepts a new host key or asks for a password. The receiver must be installed at `~/Applications/DeckDrop`. Its temporary user service keeps the window alive when SSH disconnects; it does not enable startup at login. Only the SSH host preference is saved. Pairing keys travel through encrypted SSH standard input and the Deck's private local socket, without appearing in process arguments or being written to disk. The Deck uses the SSH connection's IPv4 source address to reach the Mac, so no network-interface selection is needed for automatic pairing. VPNs, jump hosts, and IPv6-only routes may require manual pairing.

For manual pairing, click **Copy pairing link**, transfer it privately to the Deck, paste it into the receiver, and click **Connect**. Automatic discovery and short numeric codes are not implemented.

The pairing link combines the server address, a fresh random access key, and a certificate fingerprint. The Deck verifies the encrypted connection before sending the key. No Mac login password or Windows File Sharing setup is required for this flow. Links grant read access to the selected folder and must be kept private. They are not persisted between launches.

Transfers stream to disk and preserve existing destination folders. Interrupted copies are marked incomplete; resume and filesystem metadata preservation are not implemented. See the receiver README for installation, limits, and tests.

## SMB fallback

1. Open Deck Drop.app and choose your source folder.
2. Click Open Sharing Settings. Enable File Sharing and add that folder to Shared Folders. Open Options and enable **Share files and folders using SMB**. Under **Windows File Sharing**, tick your Mac account and enter its Mac login password. This separate account checkbox is required for Steam Deck access, even though the Deck runs Linux. Read-only access is enough for the Deck to copy files from the Mac.
3. Return to Deck Drop and click Refresh. The status checks whether this Mac accepts a local TCP connection on SMB port 445. It does not test authentication, folder permissions, or reachability from the Deck.
4. On the same local network, put the Deck in Desktop Mode. In Dolphin, press Ctrl+L and type the displayed smb:// address.
5. Sign in with your Mac account username and password. Open the shared folder and copy it to your microSD, shown in Dolphin's sidebar.

For the SMB fallback, keep both devices awake until copying finishes. Deck Drop can be closed during the transfer: macOS serves the files, and Dolphin copies them. Remove the share or disable File Sharing afterward if you no longer need it.

## What the SMB fallback does

- Selects a folder and opens it in Finder.
- Lists active Wi-Fi/Ethernet/bridge IPv4 addresses, with a selector when there are several.
- Copies the Mac's SMB server address or the selected folder path.
- Opens the macOS Sharing settings and gives the corresponding setup steps.
- Checks for a local SMB listener and displays the system's share listing under Details.
- Refreshes on activation or on request.

In the SMB fallback, choosing a folder does not share it automatically. That flow does not configure SMB, store credentials, mount the Deck, or copy files itself. Sharing remains controlled by macOS. IPv6-only networks are not supported by the address display. A read-only setup assistant avoids installing a privileged helper for a one-time setup.

## Build

Open `DeckDrop.xcodeproj` in Xcode, select the shared **DeckDrop** scheme and **My Mac**, then press **⌘R**. Debug and Release configurations use Swift 6 and local ad-hoc signing, so a development team is not required for running on your Mac. The project includes all Swift source files, the app icon, and Info.plist. SMB probes require the app to run without App Sandbox.

The Swift package and packaging script are also available:

Install Xcode or its command-line tools with Swift 6 or newer, then run:

```sh
bash build.sh
```

This builds a release executable, wraps it in an app bundle in the parent outputs folder, and signs it locally with an ad-hoc signature. The Mac app uses system frameworks and `/usr/bin/openssl` to create temporary sharing certificates; no third-party Swift packages are used. The Deck receiver uses Qt for Python. The signature is suitable for local use; public distribution would require Developer ID signing and notarization.

The interface uses SwiftUI and Observation. UI state lives in a MainActor-isolated model; blocking system probes run in a separate actor. Cancellation is checked before a completed probe updates the UI. Already-running system commands are allowed to finish; the network probe has a two-second connection timeout.

## SMB troubleshooting

- No address: connect the Mac to Wi-Fi/Ethernet and refresh.
- Several addresses: select the interface on the same network as the Deck.
- SMB not detected: enable File Sharing and SMB in System Settings, then refresh. A failed local probe can also reflect local restrictions.
- Deck cannot connect: check that the devices are on the same LAN, neither is on an isolated guest network, and macOS firewall settings permit File Sharing.
- Login rejected: use the Mac account password, not a Steam password or Apple Account password; in File Sharing → Options → **Windows File Sharing**, tick that account and enter its Mac login password. Enabling the main SMB checkbox alone is not enough.
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
- `Transfer/`: ephemeral TLS identity, read-only HTTPS server, and transfer manifest.
- `Transfer/SSHPairing.swift`: cancellable SSH invitation delivery and verified receiver acknowledgement.
- `SteamDeck/`: Python receiver, QML frontend, launcher, and protocol/integration tests.
