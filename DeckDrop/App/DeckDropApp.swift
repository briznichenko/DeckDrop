//
//  DeckDropApp.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import SwiftUI

@main
struct DeckDropApp: App {
    @State private var model = TransferViewModel()

    var body: some Scene {
        Window("Deck Drop", id: "main") {
            ContentView(model: model)
                .frame(minWidth: 900, minHeight: 660)
        }
        .defaultSize(width: 1000, height: 700)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
