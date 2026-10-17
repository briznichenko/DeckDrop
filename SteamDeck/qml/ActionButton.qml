//
//  ActionButton.qml
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import QtQuick
import QtQuick.Controls

Button {
    id: control
    property bool primary: false
    implicitHeight: 44
    implicitWidth: Math.max(100, contentItem.implicitWidth + 32)
    leftPadding: 16
    rightPadding: 16
    activeFocusOnTab: true
    opacity: enabled ? 1 : 0.4
    contentItem: Text {
        text: control.text
        color: control.primary ? "#111415" : "#eeeeee"
        font.pixelSize: 13
        font.weight: control.primary ? Font.DemiBold : Font.Medium
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: 9
        color: control.primary ? (control.down ? "#8cc98c" : "#abe8ab") : (control.hovered ? "#30383a" : "#242c2e")
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? "#abe8ab" : (control.primary ? "transparent" : "#3a4446")
    }
}
