# Transfer protocol specification

This documents the current unversioned wire format. Change both applications together when changing it. Examples below contain placeholders, not usable credentials.

## Invitation and HTTPS

Invitation format: `deckdrop://<IPv4>:<port>/#<access-key>.<certificate-fingerprint>`.

Each sharing session creates a temporary self-signed TLS certificate and random 256-bit access key encoded as unpadded URL-safe Base64. The fingerprint is the certificate's SHA-256 digest in hexadecimal. The receiver pins this digest before sending the key; it does not use public CA trust for this certificate. TLS 1.2 is the minimum.

Every HTTP request uses `Authorization: Bearer <access-key>`. The key is in the invitation fragment rather than an HTTP path or query. The server accepts read-only GET requests:

- `/manifest` returns JSON with `name`, `directories`, and `files`.
- `/files/<id>` returns the bytes of the corresponding manifest file with its declared Content-Length.

Example manifest:

```json
{
  "name": "Games",
  "directories": ["saves", "empty-folder"],
  "files": [{"id": 0, "path": "saves/profile.dat", "size": 128}]
}
```

File IDs are assigned sequentially by the sender. Paths are relative to the shared root. The receiver rejects traversal, absolute paths, invalid components, duplicate IDs/paths, and file/directory conflicts. The sender opens source components without following symlinks and verifies regular-file type and size before streaming.

Responses close the connection and disable caching. Invalid authorization yields 401, unknown resources 404, malformed requests 400, and detected file-size/type changes 409. Stopping sharing closes the listener and active connections and invalidates the session.

The protocol does not include content hashes or a filesystem snapshot. Content-Length checks detect size mismatches; same-size source changes are not an integrity guarantee. SHA-256 comparisons in live validation are separate test checks.

## Download completion

The client streams into `<name>.incomplete-<random>` under an existing destination. Each file is written to a temporary partial file, flushed and synchronized, then renamed. On completion, the staging directory becomes `<name>` or the next available numbered name. Failure removes the current partial file and preserves the incomplete directory.

## SSH helper

The Mac invokes `python3 ~/Applications/DeckDrop/pair.py` with non-interactive authentication and strict host-key checking. A newline-terminated JSON request arrives on stdin, not in process arguments.

Manual pairing request:

```json
{"invitation":"<private-link>"}
```

Automatic transfer request:

```json
{
  "action": "transfer",
  "transport": "ssh-tunnel",
  "invitation": "<private-link>",
  "destination": "/run/media/deck/<mounted-card>"
}
```

For automatic transfer the SSH connection forwards a loopback-only Deck port to the Mac's HTTPS listener. The helper connects to `127.0.0.1` through that tunnel. Direct requests instead derive the Mac address from `SSH_CONNECTION`.

The helper emits newline-delimited JSON on stdout. Progress messages precede the final response:

```json
{"type":"progress","completedBytes":64,"totalBytes":128,"currentFile":"saves/profile.dat","remainingSeconds":2.0}
{"paired":true,"completed":true,"path":"/run/media/deck/<mounted-card>/Games"}
```

`remainingSeconds` may be null while estimating. Manual pairing returns `{"paired":true}` after the receiver verifies the manifest. A failure returns `{"paired":false,"error":"<message>"}`. The Mac requires both the completion flag and destination path for automatic-copy success; a pairing-only response is insufficient.

## Receiver IPC

The helper and GUI communicate over `deckdrop-receiver.sock` in the Deck user's runtime directory. The socket is user-only (0600). Pairing requests are acknowledged after verification. Automatic-copy display messages use `action: "transfer-status"` with `start`, `progress`, `complete`, or `error` events. Replies contain `accepted` and may indicate `cancelled` so Deck cancellation can stop the helper's download.

The GUI uses a single-instance lock. Launching again activates the existing window. A helper disconnect during an externally driven transfer must leave a failure state rather than a false completion.
