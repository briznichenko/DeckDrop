//
//  Panel.qml
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: panel
    default property alias contents: inner.data
    property string number: ""
    property string heading: ""
    property string caption: ""
    implicitHeight: inner.implicitHeight + Theme.panelPadding * 2
    color: Theme.panel
    border.color: Theme.divider
    ColumnLayout {
        id: inner
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.panelPadding }
        spacing: Theme.contentSpacing
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Text {
                text: panel.number
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSize
                Layout.alignment: Qt.AlignTop
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: panel.heading
                    color: Theme.text
                    font { family: Theme.fontFamily; pixelSize: Theme.textSize; weight: Font.DemiBold }
                    wrapMode: Text.Wrap
                }
                Text {
                    Layout.fillWidth: true
                    visible: panel.caption.length > 0
                    text: panel.caption
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textSize
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
