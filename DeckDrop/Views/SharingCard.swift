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
                CardHeading("02", "Enable sharing")
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(model.smbListening ? Palette.mint : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(
                        !model.checked
                            ? "Checking…" : model.smbListening ? "SMB listening" : "SMB not detected"
                    )
                    .font(Palette.text)
                }
                .padding(8)
                .background(.white.opacity(0.04), in: Rectangle())
            }
            VStack(alignment: .leading, spacing: 7) {
                InstructionRow("1", "Enable File Sharing.")
                InstructionRow("2", "Add your folder to Shared Folders.")
                InstructionRow("3", "In Options, enable SMB.")
                InstructionRow(
                    "4", "Enable your Mac account under Windows File Sharing.")
            }
            HStack {
                Button("Open Sharing Settings", systemImage: "gearshape") { model.openSettings() }
                    .buttonStyle(.plain)
                    .font(Palette.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundStyle(Palette.background)
                    .background(Palette.mint, in: Rectangle())
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
                "Add the folder in Settings to share it. SMB status checks this Mac only."
            )
            .font(Palette.text)
            .foregroundStyle(Palette.muted)
            .fixedSize(
                horizontal: false, vertical: true)
        }
    }
}
