import SwiftUI

struct CardHeading: View {
    let number: String
    let title: String
    let subtitle: String?

    init(_ number: String, _ title: String, subtitle: String? = nil) {
        self.number = number
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(number)
                .monospacedDigit()
                .foregroundStyle(Palette.mint)
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .fontWeight(.semibold)
                if let subtitle {
                    Text(subtitle)
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
