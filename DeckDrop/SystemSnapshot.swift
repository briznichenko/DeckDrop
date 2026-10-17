//
//  SystemSnapshot.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

struct SystemSnapshot: Sendable {
    let addresses: [NetworkAddress]
    let smbListening: Bool
    let shareListing: String
}
