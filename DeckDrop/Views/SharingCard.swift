//
//  SharingCard.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import SwiftUI

struct SharingCard: View {
    @Bindable var model: TransferModel

    var body: some View {
        TransferCard {
            HStack(alignment: .top) {
                CardHeading("02", "Make it available", subtitle: "One-time setup in macOS File Sharing.")
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(model.smbListening ? Palette.mint : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(
                        !model.checked
                            ? "Checking…" : model.smbListening ? "SMB listening" : "SMB not detected"
                    )
                    .font(.system(size: 10, weight: .medium))
                }
                .padding(8)
                .background(.white.opacity(0.04), in: Capsule())
            }
            VStack(alignment: .leading, spacing: 7) {
                InstructionRow("1", "Turn on File Sharing, then open its details.")
                InstructionRow("2", "Add your chosen folder under Shared Folders.")
                InstructionRow("3", "Open Options and enable ‘Share files and folders using SMB’.")
                InstructionRow(
                    "4", "Under Windows File Sharing, tick your Mac account and enter its login password.")
            }
            HStack {
                Button("Open Sharing Settings", systemImage: "gearshape") { model.openSettings() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundStyle(Palette.background)
                    .background(Palette.mint, in: RoundedRectangle(cornerRadius: 9))
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label(model.checking ? "Checking…" : "Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(model.checking)
                Spacer()
            }
            Text(
                "Choosing a folder here does not publish it. “SMB listening” checks this Mac only; folder access and the Deck’s connection still need checking."
            )
            .font(.system(size: 10))
            .foregroundStyle(Palette.muted)
            .fixedSize(
                horizontal: false, vertical: true)
        }
    }
}
