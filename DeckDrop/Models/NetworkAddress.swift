//
//  NetworkAddress.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

struct NetworkAddress: Identifiable, Sendable, Equatable {
    let interface: String
    let host: String
    var id: String { "\(interface):\(host)" }
    var smbURL: String { "smb://\(host)" }
}
