//
//  TransferServer.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import Darwin
import Foundation
import Network
import Security

actor TransferServer {
    private var listener: NWListener?
    private var session: TransferSession?
    private var rootFolder: URL?
    private var generation = UUID()
    private var waitingForHeader: Set<UUID> = []
    private var connections: [UUID: NWConnection] = [:]
    private let queue = DispatchQueue(label: "local.deckdrop.transfer")
    private var readiness: CheckedContinuation<UInt16, Error>?

    func start(folder: URL) async throws -> TransferSession {
        stop()
        let generation = UUID()
        self.generation = generation
        let identity = try TransferIdentity.create()
        let contents = try enumerate(folder: folder)
        let tls = NWProtocolTLS.Options()
        sec_protocol_options_set_local_identity(tls.securityProtocolOptions, identity.identity)
        sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions, .TLSv12)
        let listener = try NWListener(using: NWParameters(tls: tls, tcp: NWProtocolTCP.Options()))
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in
            Task { await self?.accept(connection) }
        }
        listener.stateUpdateHandler = { [weak self] state in
            Task { await self?.listenerChanged(state, generation: generation) }
        }
        let port = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                readiness = continuation
                listener.start(queue: queue)
            }
        } onCancel: {
            Task { await self.cancelStart(generation: generation) }
        }
        try Task.checkCancellation()
        guard self.listener === listener else { throw CancellationError() }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            stop()
            throw TransferError.unavailable("Could not generate a pairing key.")
        }
        let token = Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let session = TransferSession(
            port: port, token: token, fingerprint: identity.fingerprint, manifest: contents)
        self.session = session
        rootFolder = folder.resolvingSymlinksInPath().standardizedFileURL
        return session
    }

    func stop() {
        session = nil
        rootFolder = nil
        waitingForHeader.removeAll()
        listener?.stateUpdateHandler = nil
        listener?.newConnectionHandler = nil
        listener?.cancel()
        listener = nil
        for connection in connections.values { connection.cancel() }
        connections.removeAll()
        readiness?.resume(throwing: CancellationError())
        readiness = nil
    }

    private func cancelStart(generation: UUID) {
        guard self.generation == generation else { return }
        stop()
    }

    private func listenerChanged(_ state: NWListener.State, generation: UUID) {
        guard self.generation == generation else { return }
        switch state {
        case .ready:
            if let port = listener?.port?.rawValue {
                readiness?.resume(returning: port)
                readiness = nil
            }
        case .failed(let error):
            readiness?.resume(throwing: error)
            readiness = nil
            stop()
        case .cancelled:
            readiness?.resume(throwing: CancellationError())
            readiness = nil
        default: break
        }
    }

    private func accept(_ connection: NWConnection) {
        guard session != nil, connections.count < 4 else {
            connection.cancel()
            return
        }
        let id = UUID()
        connections[id] = connection
        waitingForHeader.insert(id)
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state { Task { await self?.close(id) } }
            if case .cancelled = state { Task { await self?.close(id) } }
        }
        connection.start(queue: queue)
        Task {
            do {
                let header = try await readHeader(connection)
                waitingForHeader.remove(id)
                try await respond(header, connection: connection)
                let timeout = Task {
                    do { try await Task.sleep(for: .seconds(30)) } catch { return }
                    if let active = connections[id], active === connection { close(id) }
                }
                defer { timeout.cancel() }
                try await finishResponse(on: connection)
            } catch {}
            close(id)
        }
        Task {
            try? await Task.sleep(for: .seconds(15))
            if waitingForHeader.contains(id), let active = connections[id], active === connection {
                connection.cancel()
            }
        }
    }

    private func close(_ id: UUID) {
        waitingForHeader.remove(id)
        connections.removeValue(forKey: id)?.cancel()
    }

    private func readHeader(_ connection: NWConnection) async throws -> String {
        var data = Data()
        while data.count < 16_384 {
            let chunk = try await receive(connection)
            guard !chunk.isEmpty else { throw CancellationError() }
            data.append(chunk)
            if let range = data.range(of: Data("\r\n\r\n".utf8)) {
                return String(decoding: data[..<range.lowerBound], as: UTF8.self)
            }
        }
        throw TransferError.unavailable("Request too large.")
    }

    private func receive(_ connection: NWConnection) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: data ?? Data())
                }
            }
        }
    }

    private func send(_ data: Data, on connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(
                content: data,
                completion: .contentProcessed { error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                })
        }
    }

    private func finishResponse(on connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(
                content: nil, contentContext: .finalMessage, isComplete: true,
                completion: .contentProcessed { error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                })
        }
        while !(try await receive(connection)).isEmpty {}
    }

    private func respond(_ header: String, connection: NWConnection) async throws {
        let lines = header.components(separatedBy: "\r\n")
        let request = lines.first?.split(separator: " ") ?? []
        guard request.count == 3, request[0] == "GET", let session else {
            try await reply(400, "Bad Request", connection: connection)
            return
        }
        let headers = lines.dropFirst().reduce(into: [String: String]()) { result, line in
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                result[parts[0].lowercased()] = parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        guard headers["authorization"] == "Bearer \(session.token)" else {
            try await reply(401, "Pairing link expired or invalid", connection: connection)
            return
        }
        if request[1] == "/manifest" {
            let data = try JSONEncoder().encode(session.manifest)
            try await send(
                responseHeader(length: Int64(data.count), type: "application/json"), on: connection)
            try await send(data, on: connection)
        } else if request[1].hasPrefix("/files/"),
            let id = Int(request[1].dropFirst("/files/".count)), session.manifest.files.indices.contains(id),
            let rootFolder
        {
            let handle = try openFile(session.manifest.files[id].path, root: rootFolder)
            defer { try? handle.close() }
            var info = stat()
            guard fstat(handle.fileDescriptor, &info) == 0,
                info.st_mode & S_IFMT == S_IFREG,
                info.st_size == session.manifest.files[id].size
            else {
                try await reply(409, "Folder changed. Start a new sharing session.", connection: connection)
                return
            }
            var remaining = session.manifest.files[id].size
            try await send(
                responseHeader(length: remaining, type: "application/octet-stream"), on: connection)
            while remaining > 0 {
                guard self.session?.token == session.token else { throw CancellationError() }
                let data = try handle.read(upToCount: Int(min(remaining, 262_144))) ?? Data()
                guard !data.isEmpty else { throw TransferError.unavailable("File changed during transfer.") }
                try await send(data, on: connection)
                remaining -= Int64(data.count)
            }
        } else {
            try await reply(404, "Not Found", connection: connection)
        }
    }

    private func responseHeader(length: Int64, type: String, status: String = "200 OK") -> Data {
        Data(
            "HTTP/1.1 \(status)\r\nContent-Length: \(length)\r\nContent-Type: \(type)\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n"
                .utf8)
    }

    private func reply(_ code: Int, _ text: String, connection: NWConnection) async throws {
        let data = Data(text.utf8)
        try await send(
            responseHeader(length: Int64(data.count), type: "text/plain", status: "\(code) Error"),
            on: connection)
        try await send(data, on: connection)
    }

    private func openFile(_ relativePath: String, root: URL) throws -> FileHandle {
        let components = relativePath.split(separator: "/").map(String.init)
        guard !components.isEmpty, components.allSatisfy({ $0 != "." && $0 != ".." }) else {
            throw TransferError.unavailable("Invalid file path.")
        }
        var directory = open(root.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard directory >= 0 else { throw TransferError.unavailable("Shared folder is no longer available.") }
        defer { Darwin.close(directory) }
        for component in components.dropLast() {
            let next = openat(directory, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
            guard next >= 0 else { throw TransferError.unavailable("Shared folder changed.") }
            Darwin.close(directory)
            directory = next
        }
        let descriptor = openat(directory, components.last!, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else { throw TransferError.unavailable("Shared file is no longer available.") }
        return FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    }

    private func enumerate(folder: URL) throws -> TransferManifest {
        let root = folder.resolvingSymlinksInPath().standardizedFileURL
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]
        var enumerationError: Error?
        guard
            let enumerator = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: keys, options: [],
                errorHandler: { _, error in
                    enumerationError = error
                    return false
                })
        else { throw TransferError.unavailable("Could not read the selected folder.") }
        var files: [TransferFile] = []
        var directories: [String] = []
        for case let url as URL in enumerator {
            guard files.count + directories.count < 100_000 else {
                throw TransferError.unavailable(
                    "This folder has too many entries. Choose a smaller subfolder.")
            }
            let values = try url.resourceValues(forKeys: Set(keys))
            if values.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            let relative = url.pathComponents.suffix(enumerator.level).joined(separator: "/")
            if values.isDirectory == true { directories.append(relative) }
            if values.isRegularFile == true {
                files.append(TransferFile(id: files.count, path: relative, size: Int64(values.fileSize ?? 0)))
            }
        }
        if let enumerationError { throw enumerationError }
        return TransferManifest(name: root.lastPathComponent, directories: directories, files: files)
    }
}
