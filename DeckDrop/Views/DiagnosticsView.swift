//
//  DiagnosticsView.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import SwiftUI

struct DiagnosticsView: View {
    @Bindable var model: TransferModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Connection details")
                .font(.title2.bold())
            Text(
                "A local SMB listener does not confirm access from your Deck. Guest Wi-Fi isolation, a firewall, or account permissions can still prevent a connection."
            )
            .foregroundStyle(.secondary)
            Text("Configured shares reported by macOS")
                .font(.headline)
            ScrollView {
                Text(
                    model.shareListing.isEmpty
                        ? "No share information available. Check File Sharing in System Settings."
                        : model.shareListing
                )
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            }.frame(height: 200)
            Text(
                "When you finish, you can remove the shared folder or turn off File Sharing in System Settings. Deck Drop does not store passwords or change sharing settings."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            HStack {
                Button("Open Sharing Settings") { model.openSettings() }
                Spacer()
                Button("Done") { model.showDiagnostics = false }.keyboardShortcut(.defaultAction)
            }
        }.padding(28)
            .frame(width: 580)
    }
}
