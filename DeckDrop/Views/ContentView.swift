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
            .disabled(model.transferSession != nil || model.startingSession)
        }
    }

    private var copyStep: some View {
        TransferCard {
            CardHeading("03", "Copy on Deck")
            Text("In the Deck receiver, choose a destination and copy. Keep this app open.")
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
