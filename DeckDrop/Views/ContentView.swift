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
                VStack(alignment: .leading, spacing: 22) {
                    TransferHeader()
                    FolderCard(model: model)
                    Picker("Transfer method", selection: $model.useSMB) {
                        Text("Deck app").tag(false)
                        Text("SMB setup").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .disabled(model.transferSession != nil || model.startingSession)
                    if model.useSMB {
                        SharingCard(model: model)
                        ConnectionCard(model: model)
                    } else {
                        PairingCard(model: model)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                        Text("Keep both devices awake and on the same local network while copying.")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
                }
                .padding(32)
            }
        }
        .background(Palette.background)
        .tint(Palette.mint)
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
}
