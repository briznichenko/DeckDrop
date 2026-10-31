//
//  Theme.qml
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/18/26.
//

pragma Singleton
import QtQuick

QtObject {
    readonly property color background: "#131313"
    readonly property color sidebar: "#131313"
    readonly property color divider: "#404040"
    readonly property color panel: "#1a1a1a"
    readonly property color accent: "#ffffff"
    readonly property color text: "#ffffff"
    readonly property color muted: "#adadad"
    readonly property color button: "#131313"
    readonly property color buttonHover: "#333333"
    readonly property color fieldBorder: "#333333"
    readonly property color error: "#ffffff"
    readonly property string fontFamily: Qt.platform.os === "osx" ? "Menlo" : "monospace"
    readonly property int textSize: 14
    readonly property int sidebarWidth: 208
    readonly property int pagePadding: 28
    readonly property int panelPadding: 24
    readonly property int sectionSpacing: 20
    readonly property int contentSpacing: 16
}
