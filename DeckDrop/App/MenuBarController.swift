//
//  TransferCard.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/31/26.
//

import AppKit
import SwiftUI

@MainActor
final class MenuBarController {
    private let item: NSStatusItem
    private let popover = NSPopover()

    init(model: TransferViewModel, openWindow: @escaping () -> Void) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = item.button else { return }
        let target = MenuBarDropTarget(frame: button.bounds)
        target.autoresizingMask = [.width, .height]
        target.model = model
        target.clicked = { [weak self] in self?.togglePopover() }
        target.dropped = { [weak self] in
            self?.popover.performClose(nil)
            openWindow()
        }
        button.addSubview(target)
        button.toolTip = "Deck Drop — drop a folder or click to open"
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarPanel(model: model) { [weak self] in
            self?.popover.performClose(nil)
            openWindow()
        })
    }

    private func togglePopover() {
        guard let button = item.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

private struct MenuBarPanel: View {
    @Bindable var model: TransferViewModel
    let openWindow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Deck Drop").fontWeight(.semibold)
            if let folder = model.folder {
                Text(folder.lastPathComponent)
                    .lineLimit(2)
                    .foregroundStyle(Palette.muted)
            }
            FolderDropArea(model: model, didSelect: openWindow)
            Button("Choose folder…") {
                openWindow()
                model.chooseFolder()
            }
            .disabled(!model.canSelectFolder)
            HStack {
                Button("Open Deck Drop", action: openWindow)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(24)
        .frame(width: 360)
        .font(Palette.text)
        .foregroundStyle(Palette.accent)
        .background(Palette.background)
        .buttonStyle(TerminalButtonStyle())
        .preferredColorScheme(.dark)
    }
}

@MainActor
private final class MenuBarDropTarget: NSView {
    var model: TransferViewModel?
    var clicked: (() -> Void)?
    var dropped: (() -> Void)?
    private var isTargeted = false {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let image = NSImageView(frame: NSRect(x: (frameRect.width - 17) / 2, y: (frameRect.height - 17) / 2, width: 17, height: 17))
        image.image = NSImage(systemSymbolName: "shippingbox", accessibilityDescription: nil)
        image.contentTintColor = .labelColor
        image.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        image.isEditable = false
        addSubview(image)
        registerForDraggedTypes([.fileURL])
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Deck Drop")
        setAccessibilityHelp("Drop a folder or click to open the folder drop area")
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        if isTargeted {
            NSColor.labelColor.withAlphaComponent(0.2).setFill()
            bounds.fill()
        }

    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }

    override func mouseDown(with event: NSEvent) { clicked?() }

    override func accessibilityPerformPress() -> Bool {
        clicked?()
        return true
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard model?.canSelectFolder == true, !urls(from: sender).isEmpty else { return [] }
        isTargeted = true
        return .copy
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        draggingEntered(sender)
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) { isTargeted = false }

    override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        model?.canSelectFolder == true
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        isTargeted = false
        guard let model else { return false }
        let accepted = model.selectFolder(urls(from: sender))
        dropped?()
        return accepted
    }

    override func concludeDragOperation(_ sender: (any NSDraggingInfo)?) { isTargeted = false }

    private func urls(from sender: any NSDraggingInfo) -> [URL] {
        sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    }
}
