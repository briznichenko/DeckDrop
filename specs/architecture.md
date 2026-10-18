# Architecture and file tree

Deck Drop has two applications: a native SwiftUI Mac sender and a Python/Qt Quick Steam Deck receiver. The Mac follows lightweight MVVM with actor-based services. The Deck uses QML views, a QObject controller, and a separate transfer client.

## Project layout

```text
DeckDrop/
├── DeckDrop.xcodeproj/                 Xcode project and shared scheme
├── Package.swift                      Alternate Swift executable build
├── README.md                          Setup and usage
├── DeckDrop/                          Mac application
│   ├── App/
│   │   └── DeckDropApp.swift           Entry point and model ownership
│   ├── Models/
│   │   ├── NetworkAddress.swift
│   │   ├── SystemSnapshot.swift
│   │   └── TransferManifest.swift      Manifest, file, session, and error values
│   ├── ViewModels/
│   │   └── TransferModel.swift         UI state and workflow orchestration
│   ├── Views/
│   │   ├── ContentView.swift           Main screen and confirmation
│   │   ├── ConnectionCard.swift
│   │   ├── DiagnosticsView.swift
│   │   ├── FolderCard.swift
│   │   ├── PairingCard.swift
│   │   ├── SharingCard.swift
│   │   ├── TransferHeader.swift
│   │   ├── TransferSidebar.swift
│   │   ├── Components/                Reusable presentation pieces
│   │   │   ├── CardHeading.swift
│   │   │   ├── InstructionRow.swift
│   │   │   ├── SidebarStep.swift
│   │   │   └── TransferCard.swift
│   │   └── Style/
│   │       └── Palette.swift          Mac design tokens
│   ├── Services/
│   │   ├── System/
│   │   │   └── SystemProbe.swift      Network and SMB diagnostics
│   │   └── Transfer/
│   │       ├── SSHPairing.swift        SSH process and message handling
│   │       ├── TransferIdentity.swift  Temporary TLS identity
│   │       └── TransferServer.swift    Read-only HTTPS server
│   └── Resources/
│       ├── DeckDrop.icns
│       └── Info.plist
├── SteamDeck/                         Installable receiver folder
│   ├── main.py                        GUI entry point and composition
│   ├── pair.py                        SSH helper entry point and workflow
│   ├── install.sh                     Virtual environment and menu launcher
│   ├── run.sh                         GUI launcher
│   ├── requirements.txt
│   ├── README.md
│   ├── deckdrop/                      Python package
│   │   ├── __init__.py
│   │   ├── presentation/
│   │   │   ├── __init__.py
│   │   │   ├── controller.py          UI state, actions, and worker
│   │   │   └── qml/
│   │   │       ├── Main.qml
│   │   │       ├── ActionButton.qml
│   │   │       ├── Panel.qml
│   │   │       ├── StepLabel.qml
│   │   │       ├── Theme.qml
│   │   │       └── qmldir
│   │   ├── services/
│   │   │   ├── __init__.py
│   │   │   └── pairing.py             Local socket inbox and acknowledgements
│   │   └── transfer/
│   │       ├── __init__.py
│   │       ├── protocol.py            Validation, pinned HTTPS, disk writes
│   │       └── progress.py            Transfer time estimates
│   └── tests/
│       ├── test_protocol.py
│       ├── test_progress.py
│       ├── test_pairing.py
│       ├── test_frontend.py
│       ├── test_quick_transfer.py
│       └── live_transfer.py           Explicit live-device check
├── Tests/
│   └── MacOS/
│       ├── Harnesses/                 Executable Swift checks
│       │   ├── FolderSelectionHarness.swift
│       │   ├── QuickTransferHarness.swift
│       │   ├── SSHPairingHarness.swift
│       │   ├── SSHTransferHarness.swift
│       │   └── TransferServerHarness.swift
│       └── Fixtures/
│           └── ssh-stall.sh
├── Scripts/
│   ├── build-macos.sh                 Build and package into dist/
│   └── test-local.sh                  Local harness and receiver checks
├── specs/                             Shared product and engineering contracts
├── dist/                              Ignored app output
└── .local/                            Ignored AI guidance, logs, and scratch files
```

The ignored root `AGENTS.md` symlink points to `.local/ai/AGENTS.md` for local instruction discovery. It is not required to build either application.

## Mac responsibilities

`DeckDropApp` owns `TransferModel` through SwiftUI `@State`. Views observe it and use `@Bindable` where controls need bindings. View-only state, such as the confirmation's save-defaults checkbox, stays in the view.

`TransferModel` is the ViewModel despite its name. It is `@MainActor @Observable`: UI state and user actions belong to the main actor. It coordinates services and owns the current workflow's tasks. UserDefaults stores opted-in host, destination, and source-path defaults. Invitation secrets remain in memory.

Services perform system and transfer work. `SystemProbe`, `TransferServer`, and `SSHPairing` are actors. Actor isolation protects their mutable state, while async calls let the UI wait without doing the operation synchronously on the main actor. Cancellation and session-generation checks prevent stale work from updating a newer session.

Models carry values between layers. They do not import SwiftUI or AppKit. Services consume these values without depending on views or the ViewModel.

The current ViewModel also owns AppKit folder-picker, clipboard, and Finder actions and directly constructs services. Those are existing coupling points. Folder organization does not introduce dependency injection or change them.

## Receiver responsibilities

`main.py` creates the Qt application, single-instance lock, controller, pairing inbox, and QML engine. `pair.py` remains at the receiver root because the Mac invokes `~/Applications/DeckDrop/pair.py` through SSH. It coordinates automatic copying and receiver status messages.

QML renders controller properties and invokes slots. `Controller` maintains presentation state; its `Worker` runs blocking client operations in a QThread. Qt signals carry results and progress back to the UI thread. The local pairing service receives requests and forwards them to the controller. It also reuses the controller's byte formatter, so this existing service has a presentation dependency; the folders do not enforce strict layer isolation.

The transfer package contains the reusable HTTPS client, validation, download behavior, and time estimation. It has no Qt dependency, so protocol and progress checks can run without a graphical environment.

## Dependency direction

- Mac: App → Views / ViewModels → Services → Models. Views also read model values.
- Deck: entry points → presentation / services → transfer. The inbox receives its controller from the entry point.
- Neither application's business behavior depends on AI tooling or `.local/`.

These are folders in one Swift executable target and one Python package. There are no independently compiled feature modules, Coordinator framework, repository layer, or third-party Swift dependencies.

## Runtime transfer

The Mac creates a temporary TLS identity and serves a manifest and file bytes. The Deck pulls files and writes them to the selected destination. Automatic transfer uses an existing trusted SSH connection to run the helper and create a temporary loopback reverse tunnel. Manual invitations use the Mac's LAN IPv4 address. SMB setup is a separate diagnostic flow handled by macOS and Dolphin.
