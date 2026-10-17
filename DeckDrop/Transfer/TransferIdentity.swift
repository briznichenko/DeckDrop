//
//  TransferIdentity.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import CryptoKit
import Foundation
import Network
import Security

struct TransferIdentity {
    let identity: sec_identity_t
    let fingerprint: String

    static func create() throws -> TransferIdentity {
        guard #available(macOS 15, *) else {
            throw TransferError.unavailable(
                "Paired transfers require macOS 15 or later. SMB setup is still available.")
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let password = UUID().uuidString
        try run(
            [
                "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-sha256", "-days", "2",
                "-subj", "/CN=DeckDrop", "-keyout", "key.pem", "-out", "certificate.pem",
            ], in: directory, password: password)
        try run(
            [
                "pkcs12", "-export", "-inkey", "key.pem", "-in", "certificate.pem",
                "-out", "identity.p12", "-passout", "env:DECKDROP_IDENTITY_PASSWORD",
            ], in: directory, password: password)
        let data = try Data(contentsOf: directory.appendingPathComponent("identity.p12"))
        let options: [String: Any] = [
            kSecImportExportPassphrase as String: password,
            kSecImportToMemoryOnly as String: true,
        ]
        var items: CFArray?
        let status = SecPKCS12Import(data as CFData, options as CFDictionary, &items)
        guard status == errSecSuccess,
            let item = (items as? [[String: Any]])?.first,
            let value = item[kSecImportItemIdentity as String]
        else {
            throw TransferError.unavailable("Could not create the encrypted sharing session (\(status)).")
        }
        let identity = value as! SecIdentity
        var certificate: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess,
            let certificate, let networkIdentity = sec_identity_create(identity)
        else { throw TransferError.unavailable("Could not load the sharing certificate.") }
        let fingerprint = SHA256.hash(data: SecCertificateCopyData(certificate) as Data)
            .map { String(format: "%02x", $0) }.joined()
        return TransferIdentity(identity: networkIdentity, fingerprint: fingerprint)
    }

    private static func run(_ arguments: [String], in directory: URL, password: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        process.currentDirectoryURL = directory
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["DECKDROP_IDENTITY_PASSWORD": password], uniquingKeysWith: { _, new in new })
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        _ = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw TransferError.unavailable(
                "Could not prepare the encrypted session. Check that macOS OpenSSL is available.")
        }
    }
}
