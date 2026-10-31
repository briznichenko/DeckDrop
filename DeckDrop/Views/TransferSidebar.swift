//
//  TransferSidebar.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import SwiftUI

struct TransferSidebar: View {
    @Bindable var model: TransferViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("> Deck Drop")
                .fontWeight(.semibold)
                .foregroundStyle(Palette.accent)
            Text("Mac → Steam Deck")
                .foregroundStyle(Palette.muted)
                .padding(.top, 12)
            VStack(alignment: .leading, spacing: 28) {
                SidebarStep("01", "Choose a folder", active: model.folder != nil)
                SidebarStep(
                    "02", model.useSMB ? "Enable sharing" : "Pair your Deck",
                    active: model.useSMB ? model.smbListening
                        : model.transferSession != nil || !model.completedDestination.isEmpty)
                SidebarStep("03", "Copy on Deck", active: !model.completedDestination.isEmpty)
            }
            .padding(.top, 48)
            Spacer(minLength: 28)
            Text(model.useSMB ? "Local network · SMB" : "Encrypted connection")
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 28)
        .frame(width: 208)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.background)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Palette.border)
                .frame(width: 1)
        }
    }
}
