//
//  TransferManifest.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import Foundation

struct TransferManifest: Codable, Sendable {
    let name: String
    let directories: [String]
    let files: [TransferFile]

    var totalBytes: Int64 { files.reduce(0) { $0 + $1.size } }
}

struct TransferFile: Codable, Sendable {
    let id: Int
    let path: String
    let size: Int64
}

struct TransferSession: Sendable {
    let port: UInt16
    let token: String
    let fingerprint: String
    let manifest: TransferManifest

    func pairingLink(host: String) -> String {
        "deckdrop://\(host):\(port)/#\(token).\(fingerprint)"
    }
}

enum TransferError: LocalizedError {
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let message): message
        }
    }
}
