import AppKit
import SwiftUI

struct FolderCard: View {
    @Bindable var model: TransferModel
    @State private var isDropTargeted = false

    private var canSelectFolder: Bool {
        model.transferSession == nil && !model.startingSession && !model.quickTransferring
    }

    var body: some View {
        TransferCard {
            CardHeading("01", "Choose a folder")
            HStack(spacing: 16) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(Palette.mint)
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
                    .buttonStyle(.bordered)
                    .disabled(!canSelectFolder)
            }
            if let folder = model.folder {
                HStack(spacing: 20) {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([folder])
                    }
                    Button("Copy path") { model.copyPath() }
                }
                .buttonStyle(.borderless)
            }
        }
        .contentShape(Rectangle())
        .overlay {
            Rectangle()
                .strokeBorder(
                    isDropTargeted && canSelectFolder ? Palette.mint : .clear,
                    lineWidth: 2
                )
                .allowsHitTesting(false)
        }
        .dropDestination(for: URL.self) { urls, _ in
            model.selectFolder(urls)
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
    }
}
