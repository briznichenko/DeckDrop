//
//  TransferModel.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import AppKit
import Observation

@MainActor @Observable
final class TransferModel {
    var folder: URL?
    var addresses: [NetworkAddress] = []
    var selectedAddress = ""
    var smbListening = false
    var checking = false
    var checked = false
    var shareListing = ""
    var copied = false
    var errorMessage: String?
    var showDiagnostics = false
    var useSMB = false
    var startingSession = false
    var transferSession: TransferSession?
    var sshHost = UserDefaults.standard.string(forKey: "deckSSHHost") ?? "steamdeck"
    var pairing = false
    var pairingMessage = ""
    private let sshPairing = SSHPairing()
    private var pairingTask: Task<Void, Never>?
    private let server = TransferServer()
    private var sessionTask: Task<Void, Never>?
    private var sessionGeneration = UUID()
    private let probe = SystemProbe()

    var pairingLink: String {
        guard let host = addresses.first(where: { $0.id == selectedAddress })?.host ?? addresses.first?.host,
            let transferSession
        else { return "" }
        return transferSession.pairingLink(host: host)
    }

    func startSharing() {
        guard let folder, !startingSession, transferSession == nil else { return }
        startingSession = true
        let generation = UUID()
        sessionGeneration = generation
        sessionTask = Task {
            defer {
                if sessionGeneration == generation { startingSession = false }
            }
            do {
                let session = try await server.start(folder: folder)
                guard !Task.isCancelled, sessionGeneration == generation else { return }
                transferSession = session
                copied = false
            } catch is CancellationError {
            } catch {
                guard sessionGeneration == generation else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    func stopSharing() {
        pairingTask?.cancel()
        pairing = false
        pairingMessage = ""
        sessionGeneration = UUID()
        sessionTask?.cancel()
        transferSession = nil
        copied = false
        startingSession = true
        sessionTask = Task {
            await server.stop()
            startingSession = false
        }
    }

    func pairAutomatically() {
        guard let transferSession, !pairing else { return }
        let generation = sessionGeneration
        let host = sshHost.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(host, forKey: "deckSSHHost")
        pairing = true
        pairingMessage = "Opening Deck Drop and verifying the connection…"
        pairingTask = Task {
            defer {
                if sessionGeneration == generation { pairing = false }
            }
            do {
                try await sshPairing.pair(invitation: transferSession.pairingLink(host: "127.0.0.1"), host: host)
                guard !Task.isCancelled, sessionGeneration == generation else { return }
                pairingMessage = "Deck paired. Choose a destination on the Deck and start copying."
            } catch {
                guard !Task.isCancelled, sessionGeneration == generation else { return }
                pairingMessage = ""
                errorMessage = error.localizedDescription
            }
        }
    }

    func copyPairingLink() {
        guard !pairingLink.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pairingLink, forType: .string)
        copied = true
    }

    var connectionAddress: String {
        addresses.first(where: { $0.id == selectedAddress })?.smbURL ?? addresses.first?.smbURL ?? ""
    }

    func refresh() async {
        guard !checking else { return }
        checking = true
        defer { checking = false }
        let snapshot = await probe.snapshot()
        guard !Task.isCancelled else { return }
        addresses = snapshot.addresses
        if !addresses.contains(where: { $0.id == selectedAddress }) {
            selectedAddress = addresses.first?.id ?? ""
        }
        smbListening = snapshot.smbListening
        shareListing = snapshot.shareListing
        checked = true
    }

    func chooseFolder() {
        guard transferSession == nil, !startingSession else { return }
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = false
        picker.prompt = "Choose folder"
        picker.message = "Choose the folder you want to make available to your Steam Deck."
        guard picker.runModal() == .OK, let url = picker.url else { return }
        folder = url
    }

    func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Sharing-Settings.extension"),
            NSWorkspace.shared.open(url)
        else {
            errorMessage = "Open System Settings → General → Sharing → File Sharing."
            return
        }
    }

    func copyAddress() {
        guard !connectionAddress.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(connectionAddress, forType: .string)
        copied = true
    }

    func copyPath() {
        guard let folder else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(folder.path, forType: .string)
    }
}
