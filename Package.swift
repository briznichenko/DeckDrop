// swift-tools-version: 6.0
//
//  Package.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//
import PackageDescription

let package = Package(
    name: "DeckDrop",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "DeckDrop")]
)
