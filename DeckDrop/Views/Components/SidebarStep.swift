//
//  SidebarStep.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import SwiftUI

struct SidebarStep: View {
    let number: String
    let title: String
    let active: Bool

    init(_ number: String, _ title: String, active: Bool) {
        self.number = number
        self.title = title
        self.active = active
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(active ? "[x]" : "[ ]")
                .foregroundStyle(active ? Palette.accent : Palette.muted)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(number)
                    .monospacedDigit()
                    .foregroundStyle(Palette.muted)
                Text(title)
                    .fontWeight(.medium)
            }
        }
    }
}
