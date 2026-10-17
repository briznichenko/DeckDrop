//
//  DeckDropApp.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import SwiftUI

@main
struct DeckDropApp: App {
    @State private var model = TransferModel()

    var body: some Scene {
        Window("Deck Drop", id: "main") {
            ContentView(model: model)
                .preferredColorScheme(.dark)
                .frame(minWidth: 920, minHeight: 720)
        }
        .defaultSize(width: 1020, height: 790)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
