import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import VertexStore

Rectangle {
    id: root

    property string pkgName: ""
    property string pkgDesc: ""
    property string pkgVersion: ""
    property string pkgSource: "flatpak"
    property bool   pkgInstalled: false
    property string pkgIcon: ""
    property string flatpakTarget: "system"   // "system" | "user"

    signal installClicked(string effectiveSource)
    signal removeClicked
    signal cardClicked

    height: 82
    radius: Theme.radiusMd
    color: hov.containsMouse ? Qt.lighter(Theme.card, 1.1) : Theme.card

    Behavior on color { ColorAnimation { duration: 120 } }

    // Left accent bar by source
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        width: 3
        radius: 2
        color: {
            switch (root.pkgSource) {
                case "flatpak": return Theme.flatpakClr
                case "pacman":  return Theme.pacmanClr
                case "aur":     return Theme.aurClr
                default:        return Theme.accent
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 16
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        spacing: 14

        // Icon
        Rectangle {
            width: 44
            height: 44
            radius: 10
            color: {
                switch (root.pkgSource) {
                    case "flatpak": return Qt.rgba(0.23, 0.51, 0.96, 0.15)
                    case "pacman":  return Qt.rgba(0.13, 0.77, 0.37, 0.15)
                    case "aur":     return Qt.rgba(0.96, 0.62, 0.07, 0.15)
                    default:        return Qt.rgba(0.49, 0.23, 0.93, 0.15)
                }
            }

            Image {
                id: iconImg
                anchors.fill: parent
                anchors.margins: 4
                source: root.pkgIcon
                fillMode: Image.PreserveAspectFit
                visible: root.pkgIcon.length > 0 && status === Image.Ready
                smooth: true
                mipmap: true
            }

            Text {
                anchors.centerIn: parent
                text: root.pkgName.length > 0 ? root.pkgName[0].toUpperCase() : "?"
                font.pixelSize: 20
                font.bold: true
                visible: root.pkgIcon.length === 0 || iconImg.status !== Image.Ready
                color: {
                    switch (root.pkgSource) {
                        case "flatpak": return Theme.flatpakClr
                        case "pacman":  return Theme.pacmanClr
                        case "aur":     return Theme.aurClr
                        default:        return Theme.accent
                    }
                }
            }
        }

        // Info
        Column {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                width: parent.width
                spacing: 8

                Text {
                    text: root.pkgName
                    color: Theme.textPri
                    font.pixelSize: Theme.fontMd
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // Source badge
                Rectangle {
                    height: 18
                    width: sourceBadgeText.implicitWidth + 10
                    radius: 4
                    color: {
                        switch (root.pkgSource) {
                            case "flatpak": return Qt.rgba(0.23, 0.51, 0.96, 0.2)
                            case "pacman":  return Qt.rgba(0.13, 0.77, 0.37, 0.2)
                            case "aur":     return Qt.rgba(0.96, 0.62, 0.07, 0.2)
                            default:        return Qt.rgba(0.49, 0.23, 0.93, 0.2)
                        }
                    }
                    Text {
                        id: sourceBadgeText
                        anchors.centerIn: parent
                        text: root.pkgSource.toUpperCase()
                        font.pixelSize: 10
                        font.bold: true
                        color: {
                            switch (root.pkgSource) {
                                case "flatpak": return Theme.flatpakClr
                                case "pacman":  return Theme.pacmanClr
                                case "aur":     return Theme.aurClr
                                default:        return Theme.accent
                            }
                        }
                    }
                }

                // Version
                Text {
                    text: root.pkgVersion
                    color: Theme.textSec
                    font.pixelSize: Theme.fontSm
                }
            }

            Text {
                width: parent.width
                text: root.pkgDesc || "No description available."
                color: Theme.textSec
                font.pixelSize: Theme.fontSm
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // ── Action area (toggle + button) — wrapped so cardClicked can exclude it ──
        Row {
            id: actionArea
            spacing: 6

            // System / User toggle — flatpak uninstalled packages only
            Row {
                visible: root.pkgSource === "flatpak" && !root.pkgInstalled
                spacing: 2

                Repeater {
                    model: [
                        { label: "Sys",  value: "system" },
                        { label: "User", value: "user"   }
                    ]
                    delegate: Rectangle {
                        property bool active: root.flatpakTarget === modelData.value
                        width: 36; height: 26
                        radius: Theme.radiusSm
                        color: active ? Theme.flatpakClr : Theme.card
                        border.color: Theme.flatpakClr
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: 10
                            font.bold: true
                            color: active ? "white" : Theme.flatpakClr
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        TapHandler { onTapped: root.flatpakTarget = modelData.value }
                    }
                }
            }

            // Install / Remove button
            Rectangle {
                width: 86
                height: 32
                radius: Theme.radiusSm
                color: root.pkgInstalled ? "transparent" : Theme.accent
                border.color: root.pkgInstalled ? Theme.danger : "transparent"
                border.width: root.pkgInstalled ? 1 : 0

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: root.pkgInstalled ? "Remove" : "Install"
                    color: root.pkgInstalled ? Theme.danger : "white"
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.Medium
                }

                HoverHandler { id: btnHov }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: btnHov.hovered
                        ? (root.pkgInstalled ? Qt.rgba(0.94, 0.27, 0.27, 0.1) : Qt.rgba(1,1,1,0.1))
                        : "transparent"
                }

                TapHandler {
                    onTapped: {
                        if (root.pkgInstalled) {
                            root.removeClicked()
                        } else {
                            var src = root.pkgSource === "flatpak"
                                ? "flatpak-" + root.flatpakTarget
                                : root.pkgSource
                            root.installClicked(src)
                        }
                    }
                }
            }
        }
    }

    HoverHandler { id: hov }

    // Background tap → cardClicked, but only outside the action area
    TapHandler {
        onTapped: (eventPoint) => {
            var p = actionArea.mapFromItem(root, eventPoint.position.x, eventPoint.position.y)
            if (p.x >= 0 && p.y >= 0 && p.x <= actionArea.width && p.y <= actionArea.height) return
            root.cardClicked()
        }
    }

    // Bottom separator
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        height: 1
        color: Theme.border
        opacity: 0.5
        visible: false
    }
}
