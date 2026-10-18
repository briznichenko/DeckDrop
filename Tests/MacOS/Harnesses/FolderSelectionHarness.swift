import Foundation

@main
struct FolderSelectionHarness {
    @MainActor
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DeckDrop-FolderSelection-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("file.txt")
        try Data("test".utf8).write(to: file)
        let app = root.appendingPathComponent("Example.app")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)

        let suite = "DeckDrop.Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = TransferModel(defaults: defaults)
        precondition(model.selectFolder([root]))
        precondition(model.folder == root)

        for urls in [[], [root, root], [file], [app],
                     [URL(string: "https://example.com/folder")!],
                     [root.appendingPathComponent("missing")]] {
            model.errorMessage = nil
            precondition(!model.selectFolder(urls))
            precondition(model.folder == root)
            precondition(model.errorMessage != nil)
        }

        model.errorMessage = nil
        model.startingSession = true
        precondition(!model.selectFolder([FileManager.default.temporaryDirectory]))
        precondition(model.folder == root)
        precondition(model.errorMessage == nil)
        model.startingSession = false
        model.quickTransferring = true
        precondition(!model.selectFolder([FileManager.default.temporaryDirectory]))
        model.quickTransferring = false
        model.sshHost = "deck@example"
        model.deckDestination = "/run/media/deck/card with spaces"
        precondition(TransferModel(defaults: defaults).deckDestination.isEmpty)
        model.saveTransferDefaults()
        let restored = TransferModel(defaults: defaults)
        precondition(restored.sshHost == model.sshHost)
        precondition(restored.deckDestination == model.deckDestination)
        precondition(restored.folder?.path == root.path)
        precondition(restored.transferSession == nil)
        precondition(!restored.showTransferConfirmation)
        print("Folder validation, session locks, and opt-in defaults passed.")
    }
}
