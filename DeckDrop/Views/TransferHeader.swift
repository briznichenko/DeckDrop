//
//  TransferHeader.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import SwiftUI

struct TransferHeader: View {
    var body: some View {
        HStack {
            Text("Folder transfer")
                .fontWeight(.semibold)
            Spacer()
            Label("Local connection", systemImage: "lock.shield")
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 8)
    }
}
