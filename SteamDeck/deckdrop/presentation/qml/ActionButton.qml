//
//  ActionButton.qml
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/18/26.
//

import QtQuick
import QtQuick.Controls

Button {
    id: control
    property bool primary: false
    implicitHeight: 44
    implicitWidth: Math.max(88, contentItem.implicitWidth + 32)
    leftPadding: 16
    rightPadding: 16
    activeFocusOnTab: true
    opacity: enabled ? 1 : 0.4
    contentItem: Text {
        text: control.text
        color: control.primary ? Theme.background : Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textSize
        font.weight: Font.Medium
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: 0
        color: control.primary ? (control.down ? Theme.muted : Theme.accent) : (control.hovered || control.down ? Theme.buttonHover : Theme.button)
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus || control.hovered ? Theme.accent : Theme.muted
    }
}
