//
//  DeckDropApp.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import SwiftUI

@main
struct DeckDropApp: App {
    @NSApplicationDelegateAdaptor(DeckDropAppDelegate.self) private var delegate

    var body: some Scene {
        Window("Deck Drop", id: "main") {
            MainWindowContent(delegate: delegate)
                .frame(minWidth: 900, minHeight: 660)
        }
        .defaultSize(width: 1000, height: 700)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

private struct MainWindowContent: View {
    let delegate: DeckDropAppDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ContentView(model: delegate.model)
            .onAppear {
                delegate.installMenuBar {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
    }
}

@MainActor
final class DeckDropAppDelegate: NSObject, NSApplicationDelegate {
    let model = TransferViewModel()
    private var menuBar: MenuBarController?

    func installMenuBar(openWindow: @escaping () -> Void) {
        guard menuBar == nil else { return }
        menuBar = MenuBarController(model: model, openWindow: openWindow)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
