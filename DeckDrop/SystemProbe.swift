//
//  SystemProbe.swift
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import Darwin
import Foundation

actor SystemProbe {
    func snapshot() -> SystemSnapshot {
        let probe = run("/usr/bin/nc", ["-G", "2", "-z", "127.0.0.1", "445"])
        let shares = run("/usr/sbin/sharing", ["-l"])
        return SystemSnapshot(
            addresses: localAddresses(),
            smbListening: probe.status == 0,
            shareListing: shares.output.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func run(_ executable: String, _ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus, String(decoding: data, as: UTF8.self))
        } catch {
            return (-1, error.localizedDescription)
        }
    }

    private func localAddresses() -> [NetworkAddress] {
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0, let first else { return [] }
        defer { freeifaddrs(first) }
        var result: [NetworkAddress] = []
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = current {
            defer { current = entry.pointee.ifa_next }
            let item = entry.pointee
            guard let address = item.ifa_addr,
                Int32(address.pointee.sa_family) == AF_INET,
                item.ifa_flags & UInt32(IFF_UP) != 0,
                item.ifa_flags & UInt32(IFF_LOOPBACK) == 0
            else { continue }
            let name = String(cString: item.ifa_name)
            guard name.hasPrefix("en") || name.hasPrefix("bridge") else { continue }
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard
                getnameinfo(
                    address, socklen_t(address.pointee.sa_len), &buffer,
                    socklen_t(buffer.count), nil, 0, NI_NUMERICHOST) == 0
            else { continue }
            let host = String(
                decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            result.append(NetworkAddress(interface: name, host: host))
        }
        return result.sorted { $0.id < $1.id }
    }
}
