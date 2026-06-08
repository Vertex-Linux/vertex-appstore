import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import VertexStore

ScrollView {
    id: root
    property var backend
    contentWidth: availableWidth
    clip: true

    Column {
        width: parent.width
        spacing: 0

        // Header
        Rectangle {
            width: parent.width
            height: 72
            color: Theme.surface

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 28
                anchors.verticalCenter: parent.verticalCenter
                text: "Settings"
                color: Theme.textPri
                font.pixelSize: Theme.fontXxl
                font.bold: true
            }
        }

        Item { width: 1; height: 28 }

        // ── Appearance ──────────────────────────────────────────────────
        SectionLabel { text: "APPEARANCE" }

        Rectangle {
            x: 28
            width: parent.width - 56
            color: Theme.card
            radius: Theme.radiusLg
            height: themeRow.height + 32

            Column {
                id: themeRow
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 20
                anchors.topMargin: 16
                spacing: 14

                Text {
                    text: "Theme"
                    color: Theme.textPri
                    font.pixelSize: Theme.fontMd
                    font.weight: Font.Medium
                }
                Text {
                    text: "Choose your preferred color scheme. Saved automatically."
                    color: Theme.textSec
                    font.pixelSize: Theme.fontSm
                }

                Row {
                    spacing: 12

                    Repeater {
                        model: [
                            { key: "dark",       label: "Dark",       bg: "#0d0f18", accent: "#7c3aed" },
                            { key: "light",      label: "Light",      bg: "#f1f5f9", accent: "#7c3aed" },
                            { key: "nord",       label: "Nord",       bg: "#2e3440", accent: "#88c0d0" },
                            { key: "catppuccin", label: "Catppuccin", bg: "#1e1e2e", accent: "#cba6f7" },
                            { key: "gruvbox",    label: "Gruvbox",    bg: "#282828", accent: "#d79921" }
                        ]

                        Column {
                            spacing: 8

                            Rectangle {
                                width: 72; height: 52; radius: Theme.radiusMd
                                color: modelData.bg
                                border.color: backend.theme_name === modelData.key ? modelData.accent : "transparent"
                                border.width: 2
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                // Accent strip at bottom
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left; anchors.right: parent.right
                                    height: 10; radius: 0; color: modelData.accent
                                    // round only bottom corners
                                    Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 6; color: parent.color }
                                }
                                // bottom-corner radius mask
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left; anchors.right: parent.right
                                    height: Theme.radiusMd; color: modelData.bg
                                }

                                // check mark
                                Rectangle {
                                    visible: backend.theme_name === modelData.key
                                    anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 4
                                    width: 18; height: 18; radius: 9; color: modelData.accent
                                    Text { anchors.centerIn: parent; text: "✓"; font.pixelSize: 10; font.bold: true; color: "white" }
                                }

                                HoverHandler { id: swH }
                                Rectangle { anchors.fill: parent; radius: parent.radius; color: swH.hovered ? Qt.rgba(1,1,1,0.08) : "transparent" }
                                TapHandler { onTapped: backend.set_theme(modelData.key) }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                color: backend.theme_name === modelData.key ? Theme.accent : Theme.textSec
                                font.pixelSize: Theme.fontSm
                                font.weight: backend.theme_name === modelData.key ? Font.Medium : Font.Normal
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 20 }

        // ── Package Sources ─────────────────────────────────────────────
        SectionLabel { text: "PACKAGE SOURCES" }

        Rectangle {
            x: 28
            width: parent.width - 56
            color: Theme.card
            radius: Theme.radiusLg
            height: sourcesCol.implicitHeight

            Column {
                id: sourcesCol
                width: parent.width

                SourceToggleRow {
                    label: "Flatpak"
                    description: "Sandboxed apps from Flathub and other remotes"
                    badgeColor: Theme.flatpakClr
                    isChecked: backend.show_flatpak
                    onToggled: (v) => backend.toggle_source("flatpak", v)
                    showSep: true
                }
                SourceToggleRow {
                    label: "Pacman"
                    description: "Official Arch Linux system packages"
                    badgeColor: Theme.pacmanClr
                    isChecked: backend.show_pacman
                    onToggled: (v) => backend.toggle_source("pacman", v)
                    showSep: true
                }
                SourceToggleRow {
                    label: "AUR  (via vpkg)"
                    description: "Arch User Repository community packages"
                    badgeColor: Theme.aurClr
                    isChecked: backend.show_aur
                    onToggled: (v) => backend.toggle_source("aur", v)
                    showSep: false
                }
            }
        }

        Item { width: 1; height: 20 }

        // ── About ───────────────────────────────────────────────────────
        SectionLabel { text: "ABOUT" }

        Rectangle {
            x: 28
            width: parent.width - 56
            color: Theme.card
            radius: Theme.radiusLg
            height: aboutInner.implicitHeight + 32

            Column {
                id: aboutInner
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 24
                anchors.topMargin: 20
                spacing: 16

                Row {
                    spacing: 16

                    Rectangle {
                        width: 56; height: 56; radius: 14
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Theme.accent }
                            GradientStop { position: 1.0; color: Qt.lighter(Theme.accent, 1.4) }
                        }
                        Text { anchors.centerIn: parent; text: "V"; color: "white"; font.pixelSize: 28; font.bold: true }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Text { text: "Vertex Store"; color: Theme.textPri; font.pixelSize: Theme.fontXl; font.bold: true }
                        Text { text: "Vertex-Linux/vertex-appstore"; color: Theme.textSec; font.pixelSize: Theme.fontMd }
                        Text { text: "Package manager for Vertex Linux"; color: Theme.textSec; font.pixelSize: Theme.fontSm }
                    }
                }

                Row {
                    spacing: 8
                    Repeater {
                        model: [
                            { label: "Rust",      clr: Theme.aurClr     },
                            { label: "Qt 6 QML",  clr: Theme.flatpakClr },
                            { label: "cxx-qt",    clr: Theme.pacmanClr  },
                            { label: "Flatpak",   clr: Theme.accent     }
                        ]
                        Rectangle {
                            height: 24; width: ct.implicitWidth + 16; radius: 12
                            color: Qt.rgba(modelData.clr.r, modelData.clr.g, modelData.clr.b, 0.15)
                            Text { id: ct; anchors.centerIn: parent; text: modelData.label; color: modelData.clr; font.pixelSize: Theme.fontSm; font.weight: Font.Medium }
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 40 }
    }

    // ── Inline sub-components ──────────────────────────────────────────

    component SectionLabel: Item {
        property string text: ""
        width: parent.width
        height: 32
        Text {
            anchors.left: parent.left; anchors.leftMargin: 28
            anchors.verticalCenter: parent.verticalCenter
            text: parent.text
            color: Theme.textSec; font.pixelSize: 11; font.weight: Font.Medium; font.letterSpacing: 1.4
        }
    }

    component SourceToggleRow: Rectangle {
        property string label: ""
        property string description: ""
        property color  badgeColor: Theme.accent
        property bool   isChecked: true
        property bool   showSep: true
        signal toggled(bool value)

        width: parent.width; height: 68; color: "transparent"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 20

            Column {
                Layout.fillWidth: true; spacing: 4

                Row {
                    spacing: 8
                    Rectangle { width: 8; height: 8; radius: 4; color: badgeColor; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: label; color: Theme.textPri; font.pixelSize: Theme.fontMd; font.weight: Font.Medium }
                }
                Text { text: description; color: Theme.textSec; font.pixelSize: Theme.fontSm }
            }

            // Toggle switch
            Rectangle {
                width: 48; height: 26; radius: 13
                color: isChecked ? Theme.accent : Theme.border
                Behavior on color { ColorAnimation { duration: 200 } }

                Rectangle {
                    width: 20; height: 20; radius: 10; color: "white"
                    x: isChecked ? parent.width - width - 3 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }

                TapHandler { onTapped: toggled(!isChecked) }
            }
        }

        Rectangle {
            visible: showSep
            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
            anchors.leftMargin: 20; anchors.rightMargin: 20; height: 1; color: Theme.border; opacity: 0.5
        }
    }
}
