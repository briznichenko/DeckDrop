//
//  TransferServerHarness.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import Foundation

@main
struct TransferServerHarness {
    static func main() async throws {
        let arguments = CommandLine.arguments
        let server = TransferServer()
        let session = try await server.start(folder: URL(fileURLWithPath: arguments[1]))
        try session.pairingLink(host: "127.0.0.1").write(
            to: URL(fileURLWithPath: arguments[2]), atomically: true, encoding: .utf8)
        if arguments.count > 3 {
            while !FileManager.default.fileExists(atPath: arguments[3]) {
                try await Task.sleep(for: .milliseconds(50))
            }
            await server.stop()
        } else {
            try await Task.sleep(for: .seconds(120))
            await server.stop()
        }
    }
}
