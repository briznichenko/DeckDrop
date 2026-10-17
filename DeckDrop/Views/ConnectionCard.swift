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
            CardHeading(
                "03", "Over to your Deck", subtitle: "Desktop Mode → Dolphin → Ctrl+L → enter this address")
            if model.addresses.count > 1 {
                Picker("Network interface", selection: $model.selectedAddress) {
                    ForEach(model.addresses) { address in
                        Text("\(address.interface) · \(address.host)")
                            .tag(address.id)
                    }
                }
                .font(.system(size: 11))
            }
            HStack(spacing: 12) {
                Image(systemName: "network")
                    .foregroundStyle(Palette.mint)
                Text(
                    model.connectionAddress.isEmpty ? "No local IPv4 address found" : model.connectionAddress
                )
                .font(.system(size: 20, weight: .medium, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
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
            .background(Palette.background, in: RoundedRectangle(cornerRadius: 10))
            Text(
                model.connectionAddress.isEmpty
                    ? "Connect this Mac to Wi-Fi or Ethernet, then refresh."
                    : "Sign in as \(NSUserName()) with your Mac login password. Open the shared folder, copy it, and paste into your microSD in Dolphin’s sidebar."
            )
            .font(.system(size: 11))
            .foregroundStyle(Palette.muted)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Login rejected? In Options → Windows File Sharing, tick your Mac account.")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.muted)
                Spacer()
                Button("Details") { model.showDiagnostics = true }.buttonStyle(.borderless)
                    .font(
                        .system(size: 11))
            }
        }
    }
}
