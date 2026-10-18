import Foundation

actor SSHPairing {
    struct Progress: Decodable, Sendable {
        let completedBytes: Int64
        let totalBytes: Int64
        let currentFile: String
        var remainingSeconds: Double? = nil

        var remainingText: String {
            guard let remainingSeconds, remainingSeconds.isFinite, remainingSeconds >= 0 else {
                return "Estimating…"
            }
            let seconds = max(1, Int(min(remainingSeconds.rounded(.up), 31_536_000)))
            if seconds < 60 { return "About \(seconds)s left" }
            let minutes = (seconds + 59) / 60
            if minutes < 60 { return "About \(minutes)m left" }
            return "About \(minutes / 60)h \(minutes % 60)m left"
        }

        var fraction: Double {
            totalBytes > 0 ? min(1, Double(completedBytes) / Double(totalBytes)) : 1
        }
    }

    private var active: (id: UUID, process: Process)?
    private let executableURL: URL

    init(executableURL: URL = URL(fileURLWithPath: "/usr/bin/ssh")) {
        self.executableURL = executableURL
    }

    func pair(invitation: String, host: String) async throws {
        _ = try await execute(invitation: invitation, host: host, destination: nil)
    }

    func transfer(
        invitation: String, host: String, destination: String,
        onProgress: @escaping @Sendable (Progress) async -> Void = { _ in }
    ) async throws -> String {
        guard let path = try await execute(invitation: invitation, host: host, destination: destination, onProgress: onProgress) else {
            throw TransferError.unavailable("The Deck did not confirm the completed copy.")
        }
        return path
    }

    private func execute(
        invitation: String, host: String, destination: String?,
        onProgress: @escaping @Sendable (Progress) async -> Void = { _ in }
    ) async throws -> String? {
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
        var arguments = [
            "-T", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes",
            "-o", "ConnectTimeout=8", "-o", "ServerAliveInterval=5",
            "-o", "ServerAliveCountMax=2",
        ]
        if destination != nil {
            guard let port = URLComponents(string: invitation)?.port else {
                throw TransferError.unavailable("Invalid transfer invitation.")
            }
            arguments += ["-o", "ExitOnForwardFailure=yes", "-R", "127.0.0.1:\(port):127.0.0.1:\(port)"]
        }
        arguments += [host, "python3 ~/Applications/DeckDrop/pair.py"]
        process.arguments = arguments
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        active = (id, process)
        let timeout = destination == nil ? Task {
            try await Task.sleep(for: .seconds(30))
            terminate(id: id)
        } : nil
        defer {
            timeout?.cancel()
            if active?.id == id { active = nil }
        }
        var request = ["invitation": invitation]
        if let destination {
            request["action"] = "transfer"
            request["transport"] = "ssh-tunnel"
            request["destination"] = destination
        }
        let payload = try JSONEncoder().encode(request) + Data([10])
        let reader = Task.detached {
            var pending = Data()
            var reply = Data()
            let handle = output.fileHandleForReading
            defer { try? handle.close() }
            while true {
                let chunk = handle.availableData
                if chunk.isEmpty { break }
                pending.append(chunk)
                while let newline = pending.firstIndex(of: 10) {
                    let line = Data(pending[..<newline])
                    pending.removeSubrange(...newline)
                    if let event = try? JSONDecoder().decode(Progress.self, from: line),
                        event.completedBytes >= 0, event.totalBytes >= event.completedBytes {
                        await onProgress(event)
                    } else {
                        reply = line
                    }
                }
                if pending.count > 65_536 { pending.removeAll() }
            }
            if !pending.isEmpty { reply = pending }
            return reply
        }
        let result: Data
        do {
            let status: Int32 = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    process.terminationHandler = { completed in
                        continuation.resume(returning: completed.terminationStatus)
                    }
                    do {
                        try process.run()
                        try? output.fileHandleForWriting.close()
                    } catch {
                        try? output.fileHandleForWriting.close()
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
            result = await reader.value
            try Task.checkCancellation()
            guard status == 0 else {
                throw TransferError.unavailable(
                    "Could not contact the Deck. Check its SSH connection and receiver installation.")
            }
        } catch {
            _ = await reader.value
            try Task.checkCancellation()
            throw error
        }
        try Task.checkCancellation()
        struct Reply: Decodable {
            let paired: Bool
            let error: String?
            let completed: Bool?
            let path: String?
        }
        guard let reply = try? JSONDecoder().decode(Reply.self, from: result) else {
            throw TransferError.unavailable(
                "The Deck receiver did not confirm pairing. Update its installation and retry.")
        }
        if destination != nil {
            guard reply.paired, reply.completed == true, let path = reply.path, path.hasPrefix("/") else {
                throw TransferError.unavailable(
                    reply.error ?? "The Deck did not confirm a completed copy. Update its receiver and retry.")
            }
            return path
        }
        guard reply.paired else {
            throw TransferError.unavailable(
                reply.error ?? "The Deck could not verify this sharing session.")
        }
        return nil
    }

    private func terminate(id: UUID) {
        guard let active, active.id == id, active.process.isRunning else { return }
        active.process.terminate()
    }
}
