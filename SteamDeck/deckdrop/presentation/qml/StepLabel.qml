import QtQuick
import QtQuick.Layouts

RowLayout {
    id: step
    property string number: ""
    property string title: ""
    property bool done: false
    spacing: 12
    Text {
        Layout.preferredWidth: 20
        text: step.done ? "✓" : "○"
        color: step.done ? Theme.accent : Theme.muted
        font.pixelSize: Theme.textSize
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { text: step.number; color: Theme.muted; font.pixelSize: Theme.textSize }
        Text {
            Layout.fillWidth: true
            text: step.title
            color: Theme.text
            font { pixelSize: Theme.textSize; weight: Font.Medium }
            wrapMode: Text.Wrap
        }
    }
}
