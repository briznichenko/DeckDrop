//
//  Main.qml
//  DeckDrop
//
//  Created by Andrii Bryzhnychenko on 10/17/26.
//

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
    color: "#111415"
    font.family: "sans-serif"
    onClosing: function(close) {
        if (backend.busy) {
            close.accepted = false
            backend.cancel()
        }
    }

    FolderDialog {
        id: destinationDialog
        title: "Choose internal storage or a folder on your microSD"
        currentFolder: StandardPaths.writableLocation(StandardPaths.DownloadLocation)
        onAccepted: backend.chooseDestination(selectedFolder)
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            color: "#171b1c"
            Rectangle { anchors.right: parent.right; height: parent.height; width: 1; color: "#282d2f" }
            ColumnLayout {
                anchors.fill: parent
                anchors { leftMargin: 24; rightMargin: 20; topMargin: 38; bottomMargin: 30 }
                spacing: 0
                RowLayout {
                    spacing: 10
                    Text { text: "⇄"; color: "#abe8ab"; font { pixelSize: 27; weight: Font.Bold } }
                    Text { text: "deck drop"; color: "#eeeeee"; font { pixelSize: 23; weight: Font.DemiBold } }
                }
                Text {
                    Layout.topMargin: 14
                    text: "MAC → STEAM DECK"
                    color: "#99a6a6"
                    font { pixelSize: 10; family: "monospace"; letterSpacing: 1.2 }
                }
                ColumnLayout {
                    Layout.topMargin: 52
                    spacing: 27
                    StepLabel { number: "01"; title: "Pair your Mac"; done: backend.paired }
                    StepLabel { number: "02"; title: "Choose a destination"; done: backend.destination.length > 0 }
                    StepLabel { number: "03"; title: "Bring it over"; done: backend.state === "complete" }
                }
                Item { Layout.fillHeight: true }
                Text { text: "↓"; color: "#abe8ab"; font { pixelSize: 50; weight: Font.Light } }
                Text {
                    Layout.topMargin: 15
                    text: "Your folders.\nA little closer."
                    color: "#eeeeee"
                    font { pixelSize: 20; weight: Font.Medium }
                    lineHeight: 1.2
                }
                Text { Layout.topMargin: 14; text: "Local network · Encrypted"; color: "#99a6a6"; font.pixelSize: 11 }
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
                spacing: 20
                Item { Layout.preferredHeight: 12 }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 32
                    Layout.rightMargin: 32
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "FOLDER TRANSFER"; color: "#abe8ab"; font { pixelSize: 10; family: "monospace"; letterSpacing: 2 } }
                        Item { Layout.fillWidth: true }
                        Text { text: "STEAM DECK"; color: "#99a6a6"; font { pixelSize: 10; family: "monospace"; letterSpacing: 1 } }
                    }
                    Text { text: "A little closer to home."; color: "#eeeeee"; font { pixelSize: 32; weight: Font.DemiBold } }
                    Text {
                        Layout.fillWidth: true
                        text: "Pair with your Mac. Pick a place. Bring your files over."
                        color: "#99a6a6"
                        font.pixelSize: 14
                        wrapMode: Text.Wrap
                    }
                }
                Panel {
                    Layout.fillWidth: true
                    Layout.leftMargin: 32
                    Layout.rightMargin: 32
                    number: "01"
                    heading: backend.paired ? "Your Mac is connected" : "Pair your Mac"
                    caption: backend.paired ? "Encrypted connection verified with your private pairing link." : "On your Mac, choose a folder → Start sharing → Copy pairing link."
                    RowLayout {
                        Layout.fillWidth: true
                        visible: !backend.paired
                        spacing: 10
                        TextField {
                            id: pairingInput
                            objectName: "pairingInput"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            placeholderText: "Paste your deckdrop:// pairing link"
                            color: "#eeeeee"
                            placeholderTextColor: "#99a6a6"
                            font.pixelSize: 13
                            leftPadding: 12
                            rightPadding: 12
                            selectByMouse: true
                            enabled: !backend.busy
                            activeFocusOnTab: true
                            background: Rectangle {
                                radius: 9
                                color: "#111415"
                                border.color: pairingInput.activeFocus ? "#abe8ab" : "#3a4446"
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
                        spacing: 14
                        Rectangle {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            radius: 10
                            color: "#27362c"
                            Text { anchors.centerIn: parent; text: "✓"; color: "#abe8ab"; font.pixelSize: 23 }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            Text { Layout.fillWidth: true; text: backend.folderName; color: "#eeeeee"; font { pixelSize: 15; weight: Font.Medium } elide: Text.ElideMiddle }
                            Text { text: backend.folderDetail; color: "#99a6a6"; font.pixelSize: 12 }
                        }
                        ActionButton { text: "Disconnect"; enabled: !backend.busy; onClicked: backend.disconnectMac() }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "No Mac password. No Windows File Sharing. Keep the pairing link private."
                        color: "#99a6a6"
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }
                }
                Panel {
                    Layout.fillWidth: true
                    Layout.leftMargin: 32
                    Layout.rightMargin: 32
                    number: "02"
                    heading: "Make yourself at home"
                    caption: "Choose a folder on internal storage or your microSD."
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            Text {
                                Layout.fillWidth: true
                                text: backend.destination || "Where should your folder go?"
                                color: backend.destination ? "#eeeeee" : "#99a6a6"
                                font.pixelSize: 13
                                elide: Text.ElideMiddle
                            }
                            Text { text: "Existing folders are kept. Copies get their own folder."; color: "#99a6a6"; font.pixelSize: 11 }
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
                    Layout.leftMargin: 32
                    Layout.rightMargin: 32
                    number: "03"
                    heading: backend.state === "complete" ? "Right where you want it." : "Bring it over"
                    caption: backend.state === "complete" ? "Your folder has finished copying." : "Your Mac keeps the originals. Your Deck gets a copy."
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: backend.state === "copying" || backend.state === "complete" || backend.state === "cancelled"
                        spacing: 8
                        ProgressBar {
                            id: progressBar
                            Layout.fillWidth: true
                            value: backend.progress
                            implicitHeight: 6
                            background: Rectangle { color: "#111415"; radius: 3 }
                            contentItem: Item {
                                Rectangle { width: progressBar.visualPosition * parent.width; height: parent.height; radius: 3; color: "#abe8ab" }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { Layout.fillWidth: true; text: backend.currentFile; color: "#99a6a6"; font.pixelSize: 11; elide: Text.ElideMiddle }
                            Text { text: backend.progressText; color: "#99a6a6"; font { pixelSize: 11; family: "monospace" } }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: backend.message.length > 0
                        text: backend.message
                        color: backend.state === "error" ? "#f0bc88" : "#99a6a6"
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        ActionButton {
                            objectName: "startCopyButton"
                            text: backend.state === "complete" ? "Copy again" : "Start copying"
                            primary: true
                            enabled: backend.paired && backend.destination.length > 0 && !backend.busy
                            onClicked: backend.startCopy()
                        }
                        ActionButton { text: "Cancel"; visible: backend.busy; onClicked: backend.cancel() }
                        ActionButton { text: "Open folder"; visible: backend.state === "complete"; onClicked: backend.openResult() }
                        Item { Layout.fillWidth: true }
                        Text { text: backend.state === "complete" ? "✓ COMPLETE" : "LOCAL ONLY"; color: "#abe8ab"; font { pixelSize: 10; family: "monospace"; letterSpacing: 1 } }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 32
                    Layout.rightMargin: 32
                    Layout.bottomMargin: 24
                    text: "Keep both devices awake and on the same local network while copying."
                    color: "#99a6a6"
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
