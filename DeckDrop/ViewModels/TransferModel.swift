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
    var sshHost: String
    var deckDestination: String
    var showTransferConfirmation = false
    var quickTransferring = false
    var transferMessage = ""
    var transferProgress: SSHPairing.Progress?
    var completedDestination = ""
    private let defaults: UserDefaults
    private var quickTask: Task<Void, Never>?
    var pairing = false
    var pairingMessage = ""
    private let sshPairing = SSHPairing()
    private var pairingTask: Task<Void, Never>?
    private let server = TransferServer()
    private var sessionTask: Task<Void, Never>?
    private var sessionGeneration = UUID()
    private let probe = SystemProbe()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        sshHost = defaults.string(forKey: "deckSSHHost") ?? "steamdeck"
        deckDestination = defaults.string(forKey: "deckDestination") ?? ""
        if let path = defaults.string(forKey: "sourceFolderPath") {
            let url = URL(fileURLWithPath: path)
            if let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]),
                values.isDirectory == true, values.isPackage != true,
                FileManager.default.isReadableFile(atPath: path) {
                folder = url
            }
        }
    }

    func saveTransferDefaults() {
        defaults.set(sshHost.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "deckSSHHost")
        defaults.set(deckDestination.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "deckDestination")
        defaults.set(folder?.path, forKey: "sourceFolderPath")
    }

    func transferFolder() {
        guard let folder, !quickTransferring, !startingSession, transferSession == nil else { return }
        let host = sshHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let destination = deckDestination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, !destination.isEmpty else {
            errorMessage = "Enter the Deck host and destination."
            return
        }
        showTransferConfirmation = false
        quickTransferring = true
        completedDestination = ""
        transferProgress = nil
        transferMessage = "Preparing…"
        let generation = UUID()
        sessionGeneration = generation
        quickTask = Task {
            var result: String?
            var failure: String?
            do {
                let session = try await server.start(folder: folder)
                try Task.checkCancellation()
                guard sessionGeneration == generation else { return }
                transferSession = session
                transferMessage = "Transferring…"
                result = try await sshPairing.transfer(
                    invitation: session.pairingLink(host: "127.0.0.1"),
                    host: host, destination: destination
                ) { progress in
                    await self.updateProgress(progress, generation: generation)
                }
                try Task.checkCancellation()
            } catch is CancellationError {
            } catch {
                failure = error.localizedDescription
            }
            guard sessionGeneration == generation else { return }
            await server.stop()
            guard sessionGeneration == generation else { return }
            transferSession = nil
            quickTransferring = false
            if let result {
                completedDestination = result
                transferMessage = "Transferred"
            } else if let failure {
                transferMessage = "Transfer failed"
                errorMessage = failure
            } else {
                transferMessage = "Cancelled"
            }
        }
    }

    private func updateProgress(_ progress: SSHPairing.Progress, generation: UUID) {
        guard sessionGeneration == generation, quickTransferring else { return }
        transferProgress = progress
        transferMessage = progress.fraction >= 1 ? "Finishing…" : "Transferring…"
    }

    var pairingLink: String {
        guard let host = addresses.first(where: { $0.id == selectedAddress })?.host ?? addresses.first?.host,
            let transferSession
        else { return "" }
        return transferSession.pairingLink(host: host)
    }

    func startSharing() {
        guard let folder, !startingSession, !quickTransferring, transferSession == nil else { return }
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
        if quickTransferring { transferMessage = "Cancelled" }
        quickTask?.cancel()
        quickTransferring = false
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
        guard transferSession == nil, !startingSession, !quickTransferring else { return }
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = false
        picker.directoryURL = folder
        picker.prompt = "Choose folder"
        picker.message = "Choose the folder you want to make available to your Steam Deck."
        guard picker.runModal() == .OK, let url = picker.url else { return }
        selectFolder([url])
    }

    @discardableResult
    func selectFolder(_ urls: [URL]) -> Bool {
        guard transferSession == nil, !startingSession, !quickTransferring else { return false }
        guard urls.count == 1, let url = urls.first, url.isFileURL else {
            errorMessage = "Choose one local folder."
            return false
        }
        do {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            guard values.isDirectory == true, values.isPackage != true else {
                errorMessage = "Choose a folder, rather than a file or app."
                return false
            }
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                errorMessage = "This folder isn’t readable. Check its permissions or choose another folder."
                return false
            }
            folder = url
            completedDestination = ""
            transferMessage = ""
            transferProgress = nil
            showTransferConfirmation = !useSMB
            return true
        } catch {
            errorMessage = "Couldn’t open this folder. \(error.localizedDescription)"
            return false
        }
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
