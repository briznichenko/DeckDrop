import SwiftUI

struct TransferCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16, content: content)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background {
                Rectangle()
                    .fill(Palette.card)
            }
    }
}
