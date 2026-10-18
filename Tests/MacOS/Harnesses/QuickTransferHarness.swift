import Foundation

@main
struct QuickTransferHarness {
    @MainActor
    static func main() async throws {
        let arguments = CommandLine.arguments
        let suite = "DeckDrop.QuickTransferTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = TransferModel(defaults: defaults)
        model.sshHost = arguments[2]
        model.deckDestination = arguments[3]
        precondition(model.selectFolder([URL(fileURLWithPath: arguments[1])]))
        model.transferFolder()
        let deadline = Date().addingTimeInterval(60)
        while model.quickTransferring && Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        guard !model.quickTransferring, !model.completedDestination.isEmpty else {
            model.stopSharing()
            throw TransferError.unavailable(model.errorMessage ?? "Quick transfer did not complete.")
        }
        precondition(model.transferSession == nil)
        precondition(model.transferMessage == "Transferred")
        print(model.completedDestination)
    }
}
