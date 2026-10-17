//
//  FolderCard.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import AppKit
import SwiftUI

struct FolderCard: View {
    @Bindable var model: TransferModel

    var body: some View {
        TransferCard {
            CardHeading(
                "01", "Choose your folder",
                subtitle: "The files stay on your Mac until you copy them on the Deck.")
            HStack(spacing: 14) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 27))
                    .foregroundStyle(Palette.mint)
                    .frame(width: 52, height: 52)
                    .background(
                        Palette.mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.folder?.lastPathComponent ?? "Choose a folder to get started")
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(model.folder?.path ?? "Games, mods, saves, or anything else.")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(2)
                        .textSelection(
                            .enabled)
                }
                Spacer(minLength: 0)
                Button(model.folder == nil ? "Choose folder…" : "Change…") { model.chooseFolder() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(model.transferSession != nil || model.startingSession)
            }
            if let folder = model.folder {
                HStack {
                    Button("Show in Finder", systemImage: "arrow.up.forward.square") {
                        NSWorkspace.shared.activateFileViewerSelecting([folder])
                    }
                    Button("Copy folder path", systemImage: "doc.on.doc") { model.copyPath() }
                }
                .font(.system(size: 11))
                .buttonStyle(.borderless)
            }
        }
    }
}
