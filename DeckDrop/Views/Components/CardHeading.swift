//
//  CardHeading.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import SwiftUI

struct CardHeading: View {
    let number: String
    let title: String
    let subtitle: String

    init(_ number: String, _ title: String, subtitle: String) {
        self.number = number
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.mint)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
            }
        }
    }
}
