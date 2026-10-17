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
    let icon: String
    let active: Bool

    init(_ number: String, _ title: String, icon: String, active: Bool) {
        self.number = number
        self.title = title
        self.icon = icon
        self.active = active
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: active ? "checkmark.circle.fill" : icon)
                .foregroundStyle(active ? Palette.mint : Palette.muted)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(number)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Palette.muted)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
        }
    }
}
