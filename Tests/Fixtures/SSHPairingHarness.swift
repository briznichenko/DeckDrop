import Foundation

@main
struct SSHPairingHarness {
    static func main() async throws {
        let arguments = CommandLine.arguments
        let invitation = try String(contentsOfFile: arguments[1], encoding: .utf8)
        let pairing =
            arguments.count > 4
            ? SSHPairing(executableURL: URL(fileURLWithPath: arguments[4])) : SSHPairing()
        let task = Task { try await pairing.pair(invitation: invitation, host: arguments[2]) }
        if arguments.count > 3, arguments[3] == "cancel" {
            try await Task.sleep(for: .milliseconds(150))
            task.cancel()
            do {
                try await task.value
                throw TransferError.unavailable("Cancelled pairing unexpectedly succeeded.")
            } catch is CancellationError {
                print("Cancellation confirmed")
            }
        } else {
            try await task.value
            print("Deck verified pairing")
        }
    }
}
