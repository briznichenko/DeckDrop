# Shared UI specification

The Mac sender and Deck receiver are two interfaces of one product. Shared styling lives in `DeckDrop/Views/Style/Palette.swift` and `SteamDeck/deckdrop/presentation/qml/Theme.qml`.

- Use a dark neutral background, one neutral panel fill, white primary text, muted secondary text, and a mint accent.
- Use 14-point SwiftUI / 14-logical-pixel QML text. Establish hierarchy with weight and spacing.
- Keep panels square, content-sized, and stacked on the right, with three matching numbered steps on the left.
- Use 24-point panel padding, 28-point page padding, 16-point content spacing, and 20-point section spacing.
- Reuse the shared components on each platform. Keep wording short and functional.
- Preserve native Mac controls and Deck touch targets, including a 44-pixel minimum Deck button height and visible keyboard focus.
- Show meaningful preparing, transferring, finishing, completed, cancelled, and error states. Display byte progress and a time estimate when available.

For visual changes, inspect both platforms and update shared styling together. Verify the Mac minimum 900×660 window and Deck 1280×800 and 960×640 layouts with fresh screenshots. Preserve platform-specific actions and necessary access/error information.
