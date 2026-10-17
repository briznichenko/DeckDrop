import Foundation

actor SSHPairing {
    private var active: (id: UUID, process: Process)?
    private let executableURL: URL

    init(executableURL: URL = URL(fileURLWithPath: "/usr/bin/ssh")) {
        self.executableURL = executableURL
    }

    func pair(invitation: String, host: String) async throws {
        guard !host.isEmpty, host.count <= 253,
            host.first != "-",
            host.utf8.allSatisfy({
                (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
                    || [45, 46, 64, 95].contains($0)
            })
        else {
            throw TransferError.unavailable("Enter an SSH host such as steamdeck or deck@192.168.0.66.")
        }
        guard active == nil else { throw TransferError.unavailable("Pairing is already in progress.") }
        try Task.checkCancellation()
        let id = UUID()
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        process.executableURL = executableURL
        process.arguments = [
            "-T", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes",
            "-o", "ConnectTimeout=8", "-o", "ServerAliveInterval=5",
            "-o", "ServerAliveCountMax=2", host,
            "python3 ~/Applications/DeckDrop/pair.py",
        ]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        active = (id, process)
        let timeout = Task {
            try await Task.sleep(for: .seconds(30))
            terminate(id: id)
        }
        defer {
            timeout.cancel()
            if active?.id == id { active = nil }
        }
        let payload = try JSONEncoder().encode(["invitation": invitation]) + Data([10])
        let result: Data
        do {
            result = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    process.terminationHandler = { completed in
                        let data = output.fileHandleForReading.readDataToEndOfFile()
                        if completed.terminationStatus == 0 {
                            continuation.resume(returning: data)
                        } else {
                            continuation.resume(
                                throwing: TransferError.unavailable(
                                    "Automatic pairing failed. Keep the Deck in Desktop Mode and check its SSH connection and receiver installation. You can retry or use a pairing link."
                                ))
                        }
                    }
                    do {
                        try process.run()
                    } catch {
                        process.terminationHandler = nil
                        continuation.resume(throwing: error)
                        return
                    }
                    try? input.fileHandleForWriting.write(contentsOf: payload)
                    try? input.fileHandleForWriting.close()
                }
            } onCancel: {
                Task { await self.terminate(id: id) }
            }
        } catch {
            try Task.checkCancellation()
            throw error
        }
        try Task.checkCancellation()
        struct Reply: Decodable {
            let paired: Bool
            let error: String?
        }
        guard let reply = try? JSONDecoder().decode(Reply.self, from: result) else {
            throw TransferError.unavailable(
                "The Deck receiver did not confirm pairing. Update its installation and retry.")
        }
        guard reply.paired else {
            throw TransferError.unavailable(
                reply.error ?? "The Deck could not verify this sharing session.")
        }
    }

    private func terminate(id: UUID) {
        guard let active, active.id == id, active.process.isRunning else { return }
        active.process.terminate()
    }
}
