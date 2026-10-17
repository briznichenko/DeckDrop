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

        let model = TransferModel()
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
        print("Folder selection: valid folder, invalid drops, and session lock passed.")
    }
}
