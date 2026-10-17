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
    implicitHeight: inner.implicitHeight + 40
    color: "#1b1f21"
    radius: 15
    border.color: "#2b3032"
    ColumnLayout {
        id: inner
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
        spacing: 16
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Text {
                text: panel.number
                color: "#abe8ab"
                font { pixelSize: 12; family: "monospace" }
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 3
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5
                Text {
                    Layout.fillWidth: true
                    text: panel.heading
                    color: "#eeeeee"
                    font { pixelSize: 16; weight: Font.DemiBold }
                    wrapMode: Text.Wrap
                }
                Text {
                    Layout.fillWidth: true
                    text: panel.caption
                    color: "#99a6a6"
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
