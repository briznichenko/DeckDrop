# Shared UI specification

The Mac sender and Deck receiver are two interfaces of one product. Shared styling lives in `DeckDrop/Views/Style/Palette.swift` and `SteamDeck/deckdrop/presentation/qml/Theme.qml`.

- Use a strictly monochrome palette: #131313 background and sidebar, #1a1a1a panels, #404040 borders, white primary text and actions, and #adadad secondary text. Status must remain understandable through words and symbols without color.
- Use 14-point SwiftUI / 14-logical-pixel QML monospaced text. Establish hierarchy with weight and spacing. Use square outlined panels, buttons, and fields for a terminal-like appearance. Primary buttons use white fill with dark text. Keep the app icon white on neutral charcoal.
- Keep panels square, content-sized, and stacked on the right, with three matching numbered steps on the left.
- Use 24-point panel padding, 28-point page padding, 16-point content spacing, and 20-point section spacing.
- Reuse the shared components on each platform. Keep wording short and functional.
- Preserve native Mac controls and Deck touch targets, including a 44-pixel minimum Deck button height and visible keyboard focus.
- Show meaningful preparing, transferring, finishing, completed, cancelled, and error states. Display byte progress and a time estimate when available.

For visual changes, inspect both platforms and update shared styling together. Verify the Mac minimum 900×660 window and Deck 1280×800 and 960×640 layouts with fresh screenshots. Preserve platform-specific actions and necessary access/error information.

The Mac source-folder panel and menu bar popover show a persistent dotted folder drop area with a highlighted drag state. The menu bar icon also accepts folder drops. All folder entry points use the same validation and are locked while a transfer is active. Secondary buttons use visible muted outlines that brighten on hover or focus on both platforms.
