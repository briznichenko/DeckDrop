//
//  InstructionRow.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import SwiftUI

struct InstructionRow: View {
    let number: String
    let text: String

    init(_ number: String, _ text: String) {
        self.number = number
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Palette.mint)
            Text(text)
                .font(.system(size: 12))
        }
    }
}
