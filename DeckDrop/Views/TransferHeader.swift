//
//  TransferHeader.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import SwiftUI

struct TransferHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("FOLDER TRANSFER")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(2)
                Spacer()
                Label("Your local connection", systemImage: "lock.shield")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.muted)
            }
            .foregroundStyle(Palette.mint)
            Text("From Mac to Deck.")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
            Text("Choose a folder. Pair your Deck. Bring your files over.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
        }
    }
}
