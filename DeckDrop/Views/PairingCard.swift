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
            CardHeading("02", "Pair your Deck")
            if let session = model.transferSession {
                Label("Ready for your Deck", systemImage: "lock.shield")
                    .font(Palette.text)
                    .foregroundStyle(Palette.mint)
                Text(
                    "\(session.manifest.files.count) files · \(ByteCountFormatter.string(fromByteCount: session.manifest.totalBytes, countStyle: .file))"
                )
                .font(Palette.text)
                .foregroundStyle(Palette.muted)
                if model.addresses.count > 1 {
                    Picker("Network interface", selection: $model.selectedAddress) {
                        ForEach(model.addresses) { address in
                            Text("\(address.interface) · \(address.host)").tag(address.id)
                        }
                    }
                }
                Text("Keep your Deck awake in Desktop Mode.")
                .font(Palette.text)
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
                        .font(Palette.text)
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
                    "Anyone with the link can download this folder. Stop sharing to revoke access."
                )
                .font(Palette.text)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
                if model.pairingLink.isEmpty {
                    Text("No local address. Connect to Wi-Fi or Ethernet.")
                        .font(Palette.text)
                        .foregroundStyle(.orange)
                }
            } else {
                Text("Put your Deck in Desktop Mode. Start sharing, then pair over SSH.")
                    .foregroundStyle(Palette.muted)
                Button(model.startingSession ? "Preparing…" : "Start sharing", systemImage: "wifi") {
                    model.startSharing()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.folder == nil || model.startingSession)
            }
        }
    }
}
