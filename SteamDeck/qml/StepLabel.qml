//
//  StepLabel.qml
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

import QtQuick
import QtQuick.Layouts

RowLayout {
    property string number: ""
    property string title: ""
    property bool done: false
    spacing: 12
    Text {
        text: parent.done ? "✓" : "○"
        color: parent.done ? "#abe8ab" : "#99a6a6"
        font.pixelSize: 19
    }
    ColumnLayout {
        spacing: 5
        Text { text: parent.parent.number; color: "#99a6a6"; font { pixelSize: 10; family: "monospace" } }
        Text { text: parent.parent.title; color: "#eeeeee"; font.pixelSize: 13 }
    }
}
