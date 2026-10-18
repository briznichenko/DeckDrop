import Foundation

@main
struct SSHTransferHarness {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DeckDrop-SSHTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let invitation = "deckdrop://127.0.0.1:12345/#" + String(repeating: "a", count: 43)
            + "." + String(repeating: "b", count: 64)
        let destination = "/run/media/deck/card with spaces"
        let estimate = try JSONDecoder().decode(SSHPairing.Progress.self, from: Data(
            #"{"completedBytes":25,"totalBytes":100,"currentFile":"save.bin","remainingSeconds":61}"#.utf8))
        precondition(estimate.remainingText == "About 2m left")
        let replies = [
            "{\"paired\":true,\"completed\":true,\"path\":\"/tmp/completed\"}",
            "{\"paired\":true}",
            "{\"paired\":false,\"error\":\"Destination unavailable\"}",
            "invalid response",
        ]
        for (index, reply) in replies.enumerated() {
            let script = root.appendingPathComponent("ssh-\(index)")
            let encoded = String(data: try JSONEncoder().encode(reply), encoding: .utf8)!
            let source = """
            #!/usr/bin/python3
            import json,sys
            request=json.load(sys.stdin)
            assert request['action']=='transfer'
            assert request['transport']=='ssh-tunnel'
            assert request['destination']=='/run/media/deck/card with spaces'
            assert '127.0.0.1:12345:127.0.0.1:12345' in sys.argv
            print(\(encoded))
            """
            try source.write(to: script, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
            let ssh = SSHPairing(executableURL: script)
            do {
                let path = try await ssh.transfer(invitation: invitation, host: "steamdeck", destination: destination)
                precondition(index == 0 && path == "/tmp/completed")
            } catch {
                precondition(index != 0)
            }
        }
        let streaming = root.appendingPathComponent("ssh-streaming")
        let acknowledged = root.appendingPathComponent("progress-received")
        let source = """
        #!/usr/bin/python3
        import json,sys,time,pathlib
        json.load(sys.stdin)
        event=json.dumps({'type':'progress','completedBytes':1,'totalBytes':3000,'currentFile':'日本語.bin'})+'\\n'
        raw=event.encode()
        sys.stdout.buffer.write(raw[:13]); sys.stdout.buffer.flush()
        time.sleep(.03)
        sys.stdout.buffer.write(raw[13:]); sys.stdout.buffer.flush()
        marker=pathlib.Path('\(acknowledged.path)')
        deadline=time.monotonic()+5
        while not marker.exists() and time.monotonic()<deadline: time.sleep(.01)
        assert marker.exists(), 'Progress was buffered until process exit'
        for completed in range(2,3001):
            print(json.dumps({'type':'progress','completedBytes':completed,'totalBytes':3000,'currentFile':'日本語.bin'}))
        print(json.dumps({'paired':True,'completed':True,'path':'/tmp/streamed'}),flush=True)
        """
        try source.write(to: streaming, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: streaming.path)
        let recorder = ProgressRecorder(marker: acknowledged)
        let path = try await SSHPairing(executableURL: streaming).transfer(
            invitation: invitation, host: "steamdeck", destination: destination
        ) { progress in
            await recorder.record(progress)
        }
        precondition(path == "/tmp/streamed")
        let count = await recorder.count
        precondition(count == 3000)
        precondition(SSHPairing.Progress(completedBytes: 0, totalBytes: 0, currentFile: "Done").fraction == 1)
        let stalled = SSHPairing(executableURL: URL(fileURLWithPath: CommandLine.arguments[1]))
        let task = Task {
            try await stalled.transfer(invitation: invitation, host: "steamdeck", destination: destination)
        }
        try await Task.sleep(for: .milliseconds(150))
        task.cancel()
        do {
            _ = try await task.value
            preconditionFailure("Cancelled SSH transfer returned success")
        } catch is CancellationError {
        }
        print("SSH transfer payload, tunnel, live progress, fragmented messages, pipe draining, completion validation, and cancellation passed.")
    }
}

private actor ProgressRecorder {
    let marker: URL
    var count = 0

    init(marker: URL) { self.marker = marker }

    func record(_ progress: SSHPairing.Progress) {
        precondition(progress.completedBytes == Int64(count + 1))
        precondition(progress.currentFile == "日本語.bin")
        count += 1
        if count == 1 { try! Data().write(to: marker) }
    }
}
