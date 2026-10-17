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
                .frame(minWidth: 900, minHeight: 660)
        }
        .defaultSize(width: 1000, height: 700)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
