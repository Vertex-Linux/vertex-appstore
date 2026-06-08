import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import VertexStore

Item {
    property var backend

    signal navigateTo(int index)
    signal searchRequested(string query)

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        Column {
            width: parent.width
            spacing: 0

            // Hero banner
            Rectangle {
                width: parent.width
                height: 200

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.accent }
                    GradientStop { position: 0.6; color: Qt.darker(Theme.accent, 1.3) }
                    GradientStop { position: 1.0; color: Theme.bg }
                }

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 40
                    spacing: 10

                    Text {
                        text: "Welcome to Vertex Store"
                        font.pixelSize: Theme.fontXxl
                        font.bold: true
                        color: "white"
                    }
                    Text {
                        text: "Browse and install Flatpak apps, Pacman and AUR packages"
                        font.pixelSize: Theme.fontLg
                        color: Qt.rgba(1, 1, 1, 0.8)
                    }

                    Row {
                        spacing: 10
                        ActionButton {
                            label: "Search Apps"
                            icon: "⌕"
                            btnColor: "white"
                            textColor: Theme.accent
                            onClicked: navigateTo(3)
                        }
                        ActionButton {
                            label: "Installed"
                            outlined: true
                            btnColor: "white"
                            textColor: "white"
                            onClicked: navigateTo(1)
                        }
                    }
                }

                // Decorative circles
                Repeater {
                    model: [{x: 0.7, y: 0.2, s: 120}, {x: 0.85, y: 0.7, s: 80}, {x: 0.95, y: 0.1, s: 50}]
                    Rectangle {
                        x: parent.width * modelData.x
                        y: parent.height * modelData.y - modelData.s / 2
                        width: modelData.s
                        height: modelData.s
                        radius: modelData.s / 2
                        color: Qt.rgba(1, 1, 1, 0.05)
                    }
                }
            }

            // Source stats
            Item { width: 1; height: 28 }

            Row {
                x: 32
                spacing: 16

                Repeater {
                    model: [
                        { title: "Flatpak",  icon: "⬡", color: Theme.flatpakClr, desc: "Sandboxed apps" },
                        { title: "Pacman",   icon: "⬡", color: Theme.pacmanClr,  desc: "System packages" },
                        { title: "AUR",      icon: "⬡", color: Theme.aurClr,     desc: "Community builds" }
                    ]

                    Rectangle {
                        width: 200
                        height: 90
                        radius: Theme.radiusLg
                        color: Theme.card

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 6

                            Row {
                                spacing: 8
                                Rectangle {
                                    width: 28; height: 28; radius: 7
                                    color: Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.18)
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.icon
                                        font.pixelSize: 14
                                        color: modelData.color
                                    }
                                }
                                Text {
                                    text: modelData.title
                                    color: Theme.textPri
                                    font.pixelSize: Theme.fontLg
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            Text {
                                text: modelData.desc
                                color: Theme.textSec
                                font.pixelSize: Theme.fontSm
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 32 }

            // Section: Quick search
            Text {
                x: 32
                text: "Quick Search"
                color: Theme.textPri
                font.pixelSize: Theme.fontXl
                font.bold: true
            }

            Item { width: 1; height: 14 }

            // Quick search input
            Rectangle {
                x: 32
                width: parent.width - 64
                height: 48
                radius: Theme.radiusMd
                color: Theme.card
                border.color: quickField.activeFocus ? Theme.accent : Theme.border
                border.width: quickField.activeFocus ? 2 : 1

                Behavior on border.color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    spacing: 10

                    Text {
                        text: "⌕"
                        color: Theme.textSec
                        font.pixelSize: 18
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: quickField
                        width: parent.width - 60
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.textPri
                        font.pixelSize: Theme.fontMd
                        selectByMouse: true

                        Keys.onReturnPressed: {
                            if (text.trim().length > 0) {
                                searchRequested(text)
                            }
                        }

                        Text {
                            visible: quickField.text.length === 0
                            text: "Search for an app or package..."
                            color: Theme.textSec
                            font: quickField.font
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            Item { width: 1; height: 40 }

            // Popular categories chips
            Text {
                x: 32
                text: "Popular Categories"
                color: Theme.textPri
                font.pixelSize: Theme.fontXl
                font.bold: true
            }

            Item { width: 1; height: 14 }

            Flow {
                x: 32
                width: parent.width - 64
                spacing: 10

                Repeater {
                    model: ["Browser", "Video Player", "Music", "Office", "Terminal", "IDE", "Games", "Image Editor", "File Manager", "Chat"]

                    Rectangle {
                        height: 34
                        width: chipLabel.implicitWidth + 24
                        radius: 17
                        color: Theme.card
                        border.color: chipHov.hovered ? Theme.accent : Theme.border
                        border.width: 1

                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Text {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: modelData
                            color: chipHov.hovered ? Theme.accent : Theme.textSec
                            font.pixelSize: Theme.fontSm

                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        HoverHandler { id: chipHov }
                        TapHandler {
                            onTapped: searchRequested(modelData)
                        }
                    }
                }
            }

            Item { width: 1; height: 40 }
        }
    }
}
