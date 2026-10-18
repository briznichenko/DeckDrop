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
        font.pixelSize: Theme.textSize
        font.weight: Font.Medium
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: height / 2
        color: control.primary ? Theme.accent : (control.hovered || control.down ? Theme.buttonHover : Theme.button)
        border.width: control.activeFocus ? 2 : 0
        border.color: Theme.accent
    }
}
