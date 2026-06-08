import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import VertexStore

Rectangle {
    id: root

    property var tasks: []
    property var backend: null

    signal closed

    color: Theme.bg

    // ── Header ─────────────────────────────────────────────────────────────────
    Rectangle {
        id: header
        width: parent.width
        height: 72
        color: Theme.surface
        z: 1

        // Bottom border
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
            height: 1; color: Theme.border; opacity: 0.6
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 28
            anchors.rightMargin: 20
            spacing: 16

            // Back button
            Rectangle {
                width: 36; height: 36; radius: Theme.radiusSm
                color: backHov.hovered ? Theme.card : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                Text { anchors.centerIn: parent; text: "←"; color: Theme.textSec; font.pixelSize: 18 }
                HoverHandler { id: backHov }
                TapHandler { onTapped: root.closed() }
            }

            Text {
                text: "Task Queue"
                color: Theme.textPri
                font.pixelSize: Theme.fontXxl
                font.bold: true
            }

            // Active count chip
            Rectangle {
                visible: activeCount > 0
                width: Math.max(28, chipTxt.implicitWidth + 12); height: 24; radius: 12
                color: Theme.warning
                property int activeCount: root.tasks.filter(t => t.status === "queued" || t.status === "running").length
                Text {
                    id: chipTxt
                    anchors.centerIn: parent
                    text: parent.activeCount + " active"
                    color: "white"; font.pixelSize: 11; font.bold: true
                }
            }

            Item { Layout.fillWidth: true }

            // Clear done
            ActionButton {
                label: "Clear Done"
                outlined: true
                visible: root.tasks.some(t => t.status === "done" || t.status === "failed")
                onClicked: if (root.backend) root.backend.clear_done_tasks()
            }
        }
    }

    // ── Task list ──────────────────────────────────────────────────────────────
    Item {
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        // Empty state
        EmptyState {
            anchors.centerIn: parent
            visible: root.tasks.length === 0
            icon: "✓"
            title: "No tasks queued"
            subtitle: "Install, remove, or update packages to see progress here"
        }

        ScrollView {
            anchors.fill: parent
            contentWidth: availableWidth
            clip: true
            visible: root.tasks.length > 0

            Column {
                width: parent.width
                spacing: 0
                topPadding: 16
                bottomPadding: 24

                Repeater {
                    model: root.tasks

                    delegate: Item {
                        width: parent.width
                        height: card.height + 12
                        x: 0

                        Rectangle {
                            id: card
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 28
                            anchors.rightMargin: 28
                            radius: Theme.radiusMd
                            color: Theme.card
                            height: cardContent.implicitHeight + 28

                            // Left status bar
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top; anchors.bottom: parent.bottom
                                anchors.topMargin: 10; anchors.bottomMargin: 10
                                width: 3; radius: 2
                                color: {
                                    switch (modelData.status) {
                                        case "running": return Theme.accent
                                        case "done":    return Theme.success
                                        case "failed":  return Theme.danger
                                        default:        return Theme.textSec
                                    }
                                }
                            }

                            Column {
                                id: cardContent
                                anchors.left: parent.left; anchors.right: parent.right
                                anchors.leftMargin: 20; anchors.rightMargin: 16
                                anchors.top: parent.top; anchors.topMargin: 14
                                spacing: 10

                                // ── Row 1: name + badges + action ──────────────
                                RowLayout {
                                    width: parent.width
                                    spacing: 10

                                    // Status icon
                                    Item {
                                        width: 22; height: 22
                                        Layout.alignment: Qt.AlignVCenter

                                        Text {
                                            anchors.centerIn: parent
                                            font.pixelSize: 15
                                            text: {
                                                switch (modelData.status) {
                                                    case "done":    return "✓"
                                                    case "failed":  return "✗"
                                                    case "running": return "↻"
                                                    default:        return "◌"
                                                }
                                            }
                                            color: {
                                                switch (modelData.status) {
                                                    case "done":    return Theme.success
                                                    case "failed":  return Theme.danger
                                                    case "running": return Theme.accent
                                                    default:        return Theme.textSec
                                                }
                                            }

                                            RotationAnimator on rotation {
                                                from: 0; to: 360; duration: 1000
                                                loops: Animation.Infinite
                                                running: modelData.status === "running"
                                            }
                                        }
                                    }

                                    // Package name
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.pkg_name
                                        color: Theme.textPri
                                        font.pixelSize: Theme.fontMd
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }

                                    // Operation badge
                                    Rectangle {
                                        height: 20; radius: 4
                                        width: opLabel.implicitWidth + 10
                                        color: {
                                            switch (modelData.kind) {
                                                case "install":    return Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.18)
                                                case "remove":     return Qt.rgba(Theme.danger.r,  Theme.danger.g,  Theme.danger.b,  0.18)
                                                case "update_all": return Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.18)
                                                default:           return Qt.rgba(Theme.accent.r,  Theme.accent.g,  Theme.accent.b,  0.18)
                                            }
                                        }
                                        Text {
                                            id: opLabel
                                            anchors.centerIn: parent
                                            font.pixelSize: 10; font.bold: true
                                            text: modelData.kind === "update_all" ? "UPDATE" : modelData.kind.toUpperCase()
                                            color: {
                                                switch (modelData.kind) {
                                                    case "install":    return Theme.success
                                                    case "remove":     return Theme.danger
                                                    case "update_all": return Theme.warning
                                                    default:           return Theme.accent
                                                }
                                            }
                                        }
                                    }

                                    // Source badge
                                    Rectangle {
                                        height: 20; radius: 4
                                        width: srcLabel.implicitWidth + 10
                                        property bool isFlatpak: modelData.pkg_source.startsWith("flatpak")
                                        color: {
                                            if (isFlatpak)                   return Qt.rgba(Theme.flatpakClr.r, Theme.flatpakClr.g, Theme.flatpakClr.b, 0.18)
                                            if (modelData.pkg_source === "pacman") return Qt.rgba(Theme.pacmanClr.r,  Theme.pacmanClr.g,  Theme.pacmanClr.b,  0.18)
                                            if (modelData.pkg_source === "aur")    return Qt.rgba(Theme.aurClr.r,     Theme.aurClr.g,     Theme.aurClr.b,     0.18)
                                            return Qt.rgba(0.5, 0.5, 0.5, 0.18)
                                        }
                                        Text {
                                            id: srcLabel
                                            anchors.centerIn: parent
                                            font.pixelSize: 10; font.bold: true
                                            text: {
                                                if (modelData.pkg_source === "flatpak-system") return "FLATPAK (SYS)"
                                                if (modelData.pkg_source === "flatpak-user")   return "FLATPAK (USER)"
                                                return modelData.pkg_source.toUpperCase()
                                            }
                                            color: {
                                                if (parent.isFlatpak)                   return Theme.flatpakClr
                                                if (modelData.pkg_source === "pacman")  return Theme.pacmanClr
                                                if (modelData.pkg_source === "aur")     return Theme.aurClr
                                                return Theme.textSec
                                            }
                                        }
                                    }

                                    // Cancel button (queued only)
                                    Rectangle {
                                        visible: modelData.status === "queued"
                                        width: cancelLabel.implicitWidth + 16; height: 26; radius: Theme.radiusSm
                                        color: cancelHov.hovered ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.15) : "transparent"
                                        border.color: Theme.danger; border.width: 1
                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        Text {
                                            id: cancelLabel
                                            anchors.centerIn: parent
                                            text: "Cancel"; color: Theme.danger
                                            font.pixelSize: Theme.fontSm; font.weight: Font.Medium
                                        }
                                        HoverHandler { id: cancelHov }
                                        TapHandler {
                                            onTapped: if (root.backend) root.backend.cancel_task(modelData.id)
                                        }
                                    }
                                }

                                // ── Row 2: progress bar (running/done/failed) ──
                                Item {
                                    width: parent.width
                                    height: 8
                                    visible: modelData.status !== "queued"

                                    Rectangle {
                                        anchors.fill: parent; radius: 4
                                        color: Theme.border
                                    }
                                    Rectangle {
                                        height: parent.height; radius: 4
                                        width: parent.width * (modelData.progress / 100)
                                        color: {
                                            switch (modelData.status) {
                                                case "done":    return Theme.success
                                                case "failed":  return Theme.danger
                                                default:        return Theme.accent
                                            }
                                        }
                                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                    }
                                }

                                // ── Row 3: status message ──────────────────────
                                Text {
                                    width: parent.width
                                    text: modelData.message
                                    color: {
                                        switch (modelData.status) {
                                            case "done":   return Theme.success
                                            case "failed": return Theme.danger
                                            default:       return Theme.textSec
                                        }
                                    }
                                    font.pixelSize: Theme.fontSm
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
