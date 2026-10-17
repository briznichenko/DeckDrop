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
            CardHeading("02", "Pair your Deck", subtitle: "Connect automatically over your existing SSH connection.")
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
                Text("Open and pair the receiver from here. Your Deck needs to be awake in Desktop Mode.")
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    TextField("Deck SSH host", text: $model.sshHost)
                        .textFieldStyle(.roundedBorder)
                        .disabled(model.pairing)
                    Button(model.pairing ? "Pairing…" : "Pair automatically", systemImage: "bolt.horizontal") {
                        model.pairAutomatically()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.pairing || model.sshHost.isEmpty)
                }
                if !model.pairingMessage.isEmpty {
                    Text(model.pairingMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.mint)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
                InstructionRow("1", "Keep your Steam Deck awake in Desktop Mode.")
                InstructionRow("2", "Start sharing here, then click Pair automatically.")
                InstructionRow("3", "Choose a destination on the Deck and start copying.")
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
