import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore

ApplicationWindow {
    id: window
    required property QtObject backend
    width: 1280
    height: 800
    minimumWidth: 960
    minimumHeight: 640
    visible: true
    title: "Deck Drop"
    color: Theme.background
    font.pixelSize: Theme.textSize
    onClosing: function(close) {
        if (backend.busy) {
            close.accepted = false
            backend.cancel()
        }
    }

    FolderDialog {
        id: destinationDialog
        title: "Choose a destination"
        currentFolder: StandardPaths.writableLocation(StandardPaths.DownloadLocation)
        onAccepted: backend.chooseDestination(selectedFolder)
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.preferredWidth: Theme.sidebarWidth
            Layout.fillHeight: true
            color: Theme.sidebar
            Rectangle { anchors.right: parent.right; height: parent.height; width: 1; color: Theme.divider }
            ColumnLayout {
                anchors.fill: parent
                anchors { leftMargin: 24; rightMargin: 24; topMargin: 36; bottomMargin: 28 }
                spacing: 0
                Text {
                    text: "⇄  Deck Drop"
                    color: Theme.accent
                    font { pixelSize: Theme.textSize; weight: Font.DemiBold }
                }
                Text {
                    Layout.topMargin: 12
                    text: "Mac → Steam Deck"
                    color: Theme.muted
                    font.pixelSize: Theme.textSize
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 48
                    spacing: 28
                    StepLabel { number: "01"; title: "Pair your Mac"; done: backend.paired }
                    StepLabel { number: "02"; title: "Destination"; done: backend.destination.length > 0 }
                    StepLabel { number: "03"; title: "Copy on Deck"; done: backend.state === "complete" }
                }
                Item { Layout.fillHeight: true; Layout.minimumHeight: 28 }
                Text { text: "Encrypted connection"; color: Theme.muted; font.pixelSize: Theme.textSize }
            }
        }
        ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ColumnLayout {
                width: scroll.availableWidth
                spacing: Theme.sectionSpacing
                Item { Layout.preferredHeight: Theme.pagePadding - Theme.sectionSpacing }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.pagePadding
                    Layout.rightMargin: Theme.pagePadding
                    Text { text: "Folder transfer"; color: Theme.text; font { pixelSize: Theme.textSize; weight: Font.DemiBold } }
                    Item { Layout.fillWidth: true }
                    Text { text: "Local connection"; color: Theme.muted; font.pixelSize: Theme.textSize }
                }
                Panel {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.pagePadding
                    Layout.rightMargin: Theme.pagePadding
                    number: "01"
                    heading: backend.externalTransfer ? (backend.busy ? "Mac connected" : "Transfer from Mac") : "Pair your Mac"
                    RowLayout {
                        Layout.fillWidth: true
                        visible: !backend.paired
                        spacing: 12
                        TextField {
                            id: pairingInput
                            objectName: "pairingInput"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            placeholderText: "Pairing link from Mac"
                            color: Theme.text
                            placeholderTextColor: Theme.muted
                            font.pixelSize: Theme.textSize
                            leftPadding: 12
                            rightPadding: 12
                            selectByMouse: true
                            enabled: !backend.busy
                            activeFocusOnTab: true
                            background: Rectangle {
                                radius: 8
                                color: Theme.background
                                border.color: pairingInput.activeFocus ? Theme.accent : Theme.fieldBorder
                                border.width: pairingInput.activeFocus ? 2 : 1
                            }
                            onAccepted: if (text.length && !backend.busy) connectButton.clicked()
                        }
                        ActionButton {
                            text: "Paste"
                            enabled: !backend.busy
                            onClicked: pairingInput.text = backend.clipboardText()
                        }
                        ActionButton {
                            id: connectButton
                            objectName: "connectButton"
                            text: backend.state === "connecting" ? "Connecting…" : "Connect"
                            primary: true
                            enabled: pairingInput.text.length > 0 && !backend.busy
                            onClicked: {
                                backend.connectMac(pairingInput.text)
                                pairingInput.clear()
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        visible: backend.paired
                        spacing: 16
                        Text { text: "✓"; color: Theme.accent; font.pixelSize: Theme.textSize }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                Layout.fillWidth: true
                                text: backend.folderName
                                textFormat: Text.PlainText
                                color: Theme.text
                                font { pixelSize: Theme.textSize; weight: Font.Medium }
                                elide: Text.ElideMiddle
                            }
                            Text { text: backend.folderDetail; color: Theme.muted; font.pixelSize: Theme.textSize }
                        }
                        ActionButton { text: "Disconnect"; enabled: !backend.busy; onClicked: backend.disconnectMac() }
                    }
                }
                Panel {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.pagePadding
                    Layout.rightMargin: Theme.pagePadding
                    number: "02"
                    heading: "Destination"
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Text {
                            Layout.fillWidth: true
                            text: backend.destination || "No folder selected"
                            textFormat: Text.PlainText
                            color: backend.destination ? Theme.text : Theme.muted
                            font.pixelSize: Theme.textSize
                            elide: Text.ElideMiddle
                        }
                        ActionButton {
                            text: backend.destination ? "Change…" : "Choose folder…"
                            enabled: !backend.busy
                            onClicked: destinationDialog.open()
                        }
                    }
                }
                Panel {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.pagePadding
                    Layout.rightMargin: Theme.pagePadding
                    number: "03"
                    heading: "Copy on Deck"
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: backend.state === "copying" || backend.state === "complete" || backend.state === "cancelled" || backend.state === "error"
                        spacing: 8
                        ProgressBar {
                            id: progressBar
                            Layout.fillWidth: true
                            objectName: "transferProgress"
                            Accessible.name: "Transfer progress"
                            value: backend.progress
                            implicitHeight: 6
                            background: Rectangle { color: Theme.background }
                            contentItem: Item {
                                Rectangle { width: progressBar.visualPosition * parent.width; height: parent.height; color: Theme.accent }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: backend.currentFile === "Done" ? "" : backend.currentFile
                                textFormat: Text.PlainText
                                color: Theme.muted
                                font.pixelSize: Theme.textSize
                                elide: Text.ElideMiddle
                            }
                            Text { text: Math.round(backend.progress * 100) + "%"; color: Theme.muted; font.pixelSize: Theme.textSize }
                            Text { text: backend.progressText; color: Theme.muted; font.pixelSize: Theme.textSize }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: backend.state === "copying"
                        text: backend.progress >= 1 ? "Finishing…" : backend.remainingText
                        color: Theme.muted
                        font.pixelSize: Theme.textSize
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: backend.message.length > 0
                        text: backend.state === "complete" ? "Transferred"
                            : backend.state === "ready" ? (backend.destination ? "Ready to copy" : "Choose a destination")
                            : backend.state === "connecting" ? "Connecting…"
                            : backend.state === "copying" ? (backend.progress >= 1 ? "Finishing…" : "Copying…") : backend.message
                        textFormat: Text.PlainText
                        color: backend.state === "error" ? Theme.error : (backend.state === "complete" ? Theme.accent : Theme.muted)
                        font.pixelSize: Theme.textSize
                        wrapMode: Text.Wrap
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        ActionButton {
                            objectName: "startCopyButton"
                            visible: !backend.externalTransfer
                            text: backend.state === "complete" ? "Copy again" : "Start copying"
                            primary: true
                            enabled: backend.paired && backend.destination.length > 0 && !backend.busy
                            onClicked: backend.startCopy()
                        }
                        ActionButton { text: "Cancel"; visible: backend.busy; onClicked: backend.cancel() }
                        ActionButton { text: "Open folder"; visible: backend.state === "complete"; onClicked: backend.openResult() }
                        Item { Layout.fillWidth: true }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.pagePadding
                    Layout.rightMargin: Theme.pagePadding
                    Layout.bottomMargin: Theme.pagePadding
                    text: "Same network · Keep both devices awake."
                    color: Theme.muted
                    font.pixelSize: Theme.textSize
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
