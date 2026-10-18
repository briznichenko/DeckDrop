import SwiftUI

struct TransferSidebar: View {
    @Bindable var model: TransferModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Deck Drop", systemImage: "arrow.down.right.and.arrow.up.left")
                .fontWeight(.semibold)
                .foregroundStyle(Palette.mint)
            Text("Mac → Steam Deck")
                .foregroundStyle(Palette.muted)
                .padding(.top, 12)
            VStack(alignment: .leading, spacing: 28) {
                SidebarStep("01", "Choose a folder", icon: "folder", active: model.folder != nil)
                SidebarStep(
                    "02", model.useSMB ? "Enable sharing" : "Pair your Deck", icon: "wifi",
                    active: model.useSMB ? model.smbListening
                        : model.transferSession != nil || !model.completedDestination.isEmpty)
                SidebarStep("03", "Copy on Deck", icon: "gamecontroller", active: !model.completedDestination.isEmpty)
            }
            .padding(.top, 48)
            Spacer(minLength: 28)
            Text(model.useSMB ? "Local network · SMB" : "Encrypted connection")
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 28)
        .frame(width: 208)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.white.opacity(0.025))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(width: 1)
        }
    }
}
