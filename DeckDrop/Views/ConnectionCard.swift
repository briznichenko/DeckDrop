//
//  ConnectionCard.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import AppKit
import SwiftUI

struct ConnectionCard: View {
    @Bindable var model: TransferModel

    var body: some View {
        TransferCard {
            CardHeading("03",
                "Copy on Deck", subtitle: "Dolphin → Ctrl+L → paste address")
            if model.addresses.count > 1 {
                Picker("Network interface", selection: $model.selectedAddress) {
                    ForEach(model.addresses) { address in
                        Text("\(address.interface) · \(address.host)")
                            .tag(address.id)
                    }
                }
                .font(Palette.text)
            }
            HStack(spacing: 12) {
                Image(systemName: "network")
                    .foregroundStyle(Palette.mint)
                Text(
                    model.connectionAddress.isEmpty ? "No local IPv4 address found" : model.connectionAddress
                )
                .font(Palette.text)
                .textSelection(.enabled)
                .lineLimit(1)
                Spacer(minLength: 0)
                Button {
                    model.copyAddress()
                } label: {
                    Label(
                        model.copied ? "Copied" : "Copy",
                        systemImage: model.copied ? "checkmark" : "doc.on.doc"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(model.connectionAddress.isEmpty)
            }
            .padding(16)
            .background(Palette.background, in: Rectangle())
            Text(
                model.connectionAddress.isEmpty
                    ? "Connect to Wi-Fi or Ethernet, then refresh."
                    : "Sign in as \(NSUserName()) with your Mac password. Copy the shared folder to your Deck."
            )
            .font(Palette.text)
            .foregroundStyle(Palette.muted)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Login trouble? Check SMB account access.")
                    .font(Palette.text)
                    .foregroundStyle(Palette.muted)
                Spacer()
                Button("Details") { model.showDiagnostics = true }.buttonStyle(.borderless)
                    .font(Palette.text)
            }
        }
    }
}
