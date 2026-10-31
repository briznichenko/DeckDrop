//
//  Palette.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import SwiftUI

enum Palette {
    static let background = Color(white: 0.075)
    static let card = Color(white: 0.10)
    static let border = Color(white: 0.25)
    static let accent = Color.white
    static let muted = Color(white: 0.68)
    static let text = Font.system(size: 14, design: .monospaced)
}

struct TerminalButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Palette.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .foregroundStyle(primary ? Palette.background : Palette.accent)
            .background(primary ? Palette.accent : (isHovered ? Palette.card : Palette.background))
            .overlay {
                Rectangle().strokeBorder(isFocused || isHovered ? Palette.accent : Palette.muted, lineWidth: isFocused ? 2 : 1)
            }
            .onHover { isHovered = $0 }
            .opacity(isEnabled ? (configuration.isPressed ? 0.65 : 1) : 0.4)
    }
}
