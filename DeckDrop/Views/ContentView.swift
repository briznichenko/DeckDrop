//
//  ContentView.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import SwiftUI

struct ContentView: View {
    @Bindable var model: TransferModel
    @Environment(\.scenePhase) private var phase
    @State private var saveAsDefault = false

    var body: some View {
        HStack(spacing: 0) {
            TransferSidebar(model: model)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TransferHeader()
                    FolderCard(model: model)
                    transferMethod
                    if model.useSMB {
                        SharingCard(model: model)
                        ConnectionCard(model: model)
                    } else {
                        PairingCard(model: model)
                        copyStep
                    }
                    Label("Same network · Keep both devices awake.", systemImage: "wifi")
                        .foregroundStyle(Palette.muted)
                }
                .padding(28)
            }
        }
        .font(Palette.text)
        .foregroundStyle(.white)
        .background(Palette.background)
        .tint(Palette.mint)
        .controlSize(.large)
        .task { await model.refresh() }
        .onChange(of: phase) { _, value in
            if value == .active { Task { await model.refresh() } }
        }
        .onChange(of: model.pairingLink) { _, _ in model.copied = false }
        .onChange(of: model.connectionAddress) { _, _ in model.copied = false }
        .alert(
            "Deck Drop",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .sheet(isPresented: $model.showDiagnostics) { DiagnosticsView(model: model) }
        .sheet(isPresented: $model.showTransferConfirmation) {
            transferConfirmation
        }
    }

    private var transferMethod: some View {
        HStack(spacing: 16) {
            Text("Transfer method")
                .foregroundStyle(Palette.muted)
            Picker("Transfer method", selection: $model.useSMB) {
                Text("Deck app").tag(false)
                Text("SMB setup").tag(true)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)
            .disabled(model.transferSession != nil || model.startingSession || model.quickTransferring)
        }
    }

    private var copyStep: some View {
        TransferCard {
            CardHeading("03", "Copy on Deck")
            if let progress = model.transferProgress {
                VStack(alignment: .leading, spacing: 8) {
                    GeometryReader { geometry in
                        Rectangle().fill(Palette.background)
                        Rectangle().fill(Palette.mint)
                            .frame(width: geometry.size.width * progress.fraction)
                    }
                    .frame(height: 6)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Transfer progress")
                    .accessibilityValue(Text(progress.fraction, format: .percent.precision(.fractionLength(0))))
                    HStack(spacing: 16) {
                        Text(progress.currentFile == "Done" ? "" : progress.currentFile)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(progress.fraction, format: .percent.precision(.fractionLength(0)))
                        Text("\(ByteCountFormatter.string(fromByteCount: progress.completedBytes, countStyle: .decimal)) / \(ByteCountFormatter.string(fromByteCount: progress.totalBytes, countStyle: .decimal))")
                    }
                    .foregroundStyle(Palette.muted)
                    if model.quickTransferring {
                        Text(progress.fraction >= 1 ? "Finishing…" : progress.remainingText)
                            .foregroundStyle(Palette.muted)
                    }
                }
            } else if model.quickTransferring {
                ProgressView().progressViewStyle(.linear)
                    .accessibilityLabel("Preparing transfer")
            }
            if model.quickTransferring {
                HStack(spacing: 12) {
                    Text(model.transferMessage)
                    Spacer()
                    Button("Cancel") { model.stopSharing() }
                }
            } else if !model.transferMessage.isEmpty {
                Label(model.transferMessage, systemImage: model.completedDestination.isEmpty ? "info.circle" : "checkmark.circle.fill")
                    .foregroundStyle(Palette.mint)
                if !model.completedDestination.isEmpty {
                    Text(model.completedDestination)
                        .foregroundStyle(Palette.muted)
                        .textSelection(.enabled)
                }
            } else {
                Text("Drop a folder, confirm, and keep this app open.")
                    .foregroundStyle(Palette.muted)
            }
        }
    }

    private var transferConfirmation: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Transfer \(model.folder?.lastPathComponent ?? "folder")")
                .fontWeight(.semibold)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 16) {
                GridRow {
                    Text("Deck host")
                    TextField("steamdeck", text: $model.sshHost)
                }
                GridRow {
                    Text("Destination")
                    TextField("/run/media/deck/your-card", text: $model.deckDestination)
                }
            }
            .textFieldStyle(.roundedBorder)
            Toggle("Save as default", isOn: $saveAsDefault)
                .toggleStyle(.checkbox)
            Text("Existing folders are kept. Copies get a numbered name.")
                .foregroundStyle(Palette.muted)
            HStack {
                Button("Cancel") { model.showTransferConfirmation = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("OK") {
                    if saveAsDefault { model.saveTransferDefaults() }
                    model.transferFolder()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(model.sshHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || model.deckDestination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .font(Palette.text)
        .padding(28)
        .frame(width: 520)
        .onAppear { saveAsDefault = false }
    }
}
