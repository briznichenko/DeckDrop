import SwiftUI

struct InstructionRow: View {
    let number: String
    let text: String

    init(_ number: String, _ text: String) {
        self.number = number
        self.text = text
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(number)
                .foregroundStyle(Palette.mint)
                .frame(width: 16)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
