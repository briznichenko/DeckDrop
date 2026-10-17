//
//  PairingCard.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import SwiftUI

struct PairingCard: View {
    @Bindable var model: TransferModel

    var body: some View {
        TransferCard {
            CardHeading("02", "Pair your Deck", subtitle: "One link. No Mac account password.")
            if let session = model.transferSession {
                Label("Ready for your Deck", systemImage: "lock.shield")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.mint)
                Text(
                    "\(session.manifest.files.count) files · \(ByteCountFormatter.string(fromByteCount: session.manifest.totalBytes, countStyle: .file))"
                )
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                if model.addresses.count > 1 {
                    Picker("Network interface", selection: $model.selectedAddress) {
                        ForEach(model.addresses) { address in
                            Text("\(address.interface) · \(address.host)").tag(address.id)
                        }
                    }
                }
                Text("Paste the pairing link into Deck Drop on your Steam Deck. Choose where to save the folder, then start copying.")
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Button(
                        model.copied ? "Link copied" : "Copy pairing link",
                        systemImage: model.copied ? "checkmark" : "link"
                    ) {
                        model.copyPairingLink()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.pairingLink.isEmpty)
                    Button("Stop sharing", role: .destructive) { model.stopSharing() }
                        .buttonStyle(.bordered)
                }
                Text(
                    "Keep this link private: anyone with it can download this folder while sharing is active. Stop sharing to revoke it. Keep the Mac app open until copying finishes."
                )
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
                if model.pairingLink.isEmpty {
                    Text("No local address found. Connect to Wi-Fi or Ethernet and reopen the window.")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
            } else {
                InstructionRow("1", "Open Deck Drop in Desktop Mode on your Steam Deck.")
                InstructionRow("2", "Start sharing here, then copy your private pairing link.")
                InstructionRow("3", "Paste it on the Deck and choose a destination folder.")
                Button(model.startingSession ? "Preparing…" : "Start sharing", systemImage: "wifi") {
                    model.startSharing()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.folder == nil || model.startingSession)
                Text(
                    "Your selected folder is served directly by Deck Drop. macOS File Sharing can stay off. Requires macOS 15 or later."
                )
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
