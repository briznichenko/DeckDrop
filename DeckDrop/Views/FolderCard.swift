//
//  FolderCard.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import AppKit
import SwiftUI

struct FolderCard: View {
    @Bindable var model: TransferViewModel

    var body: some View {
        TransferCard {
            CardHeading("01", "Choose a folder")
            HStack(spacing: 16) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(Palette.accent)
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.folder?.lastPathComponent ?? "Drop a folder here")
                        .fontWeight(.medium)
                        .lineLimit(2)
                    if let folder = model.folder {
                        Text(folder.path)
                            .foregroundStyle(Palette.muted)
                            .lineLimit(3)
                            .textSelection(.enabled)
                    }
                }
                Spacer(minLength: 0)
                Button(model.folder == nil ? "Choose folder…" : "Change…") { model.chooseFolder() }
                    .buttonStyle(TerminalButtonStyle())
                    .disabled(!model.canSelectFolder)
            }
            FolderDropArea(model: model)
            if let folder = model.folder {
                HStack(spacing: 20) {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([folder])
                    }
                    Button("Copy path") { model.copyPath() }
                }
                .buttonStyle(TerminalButtonStyle())
            }
        }
    }
}

struct FolderDropArea: View {
    @Bindable var model: TransferViewModel
    var didSelect: () -> Void = {}
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.plus")
            Text(model.canSelectFolder ? (isTargeted ? "Release to select folder" : "Drag & drop a folder here") : "Folder locked during transfer")
                .fontWeight(.medium)
            Text(model.canSelectFolder ? "Or use Choose folder" : "Stop the transfer to change folders")
                .foregroundStyle(Palette.muted)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 104)
        .padding(12)
        .background(isTargeted && model.canSelectFolder ? Palette.border : Palette.background)
        .overlay {
            Rectangle()
                .strokeBorder(
                    model.canSelectFolder ? (isTargeted ? Palette.accent : Palette.muted) : Palette.border,
                    style: StrokeStyle(lineWidth: 1, dash: [2, 5])
                )
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .dropDestination(for: URL.self) { urls, _ in
            let accepted = model.selectFolder(urls)
            didSelect()
            return accepted
        } isTargeted: { isTargeted = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Folder drop area")
        .accessibilityHint("Drop one local folder to select it for transfer")
    }
}
