//
//  TransferSidebar.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import SwiftUI

struct TransferSidebar: View {
    @Bindable var model: TransferModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.mint)
                Text("deck drop")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
            }
            .padding(.top, 38)
            Text("MAC → STEAM DECK")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(Palette.muted)
                .padding(.top, 14)
            VStack(alignment: .leading, spacing: 24) {
                SidebarStep("01", "Pick a folder", icon: "folder", active: model.folder != nil)
                SidebarStep("02", "Enable sharing", icon: "wifi", active: model.smbListening)
                SidebarStep("03", "Copy on Deck", icon: "gamecontroller", active: false)
            }
            .padding(.top, 56)
            Spacer()
            Image(systemName: "laptopcomputer.and.arrow.down")
                .font(.system(size: 42, weight: .ultraLight))
                .foregroundStyle(Palette.mint.opacity(0.8))
                .padding(.bottom, 18)
            Text("Your folders.\nA little closer.")
                .font(.system(size: 18, weight: .medium))
                .lineSpacing(3)
            Text("Local network · SMB")
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted)
                .padding(.top, 10)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .frame(width: 208)
        .frame(maxHeight: .infinity)
        .background(.white.opacity(0.025))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(width: 1)
        }
    }
}
