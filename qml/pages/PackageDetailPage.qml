import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import VertexStore

Rectangle {
    id: root
    color: Theme.bg

    property var pkg: null          // basic Package data
    property var details: null      // PackageDetails from backend
    property bool detailLoading: false
    property var backend: null
    property string flatpakTarget: "system"
    property string lightboxUrl: ""
    property bool showLightbox: false

    signal closed
    signal installRequested(string effectiveSource)
    signal removeRequested

    onPkgChanged: {
        details = null
        detailLoading = pkg !== null
        flatpakTarget = "system"
    }

    // Block all pointer events from reaching the package list below.
    // Declared first so it sits behind all interactive children in paint/event order;
    // header (z:1) and lightbox (z:100) are still delivered events before this.
    MouseArea { anchors.fill: parent }

    // Receive details from backend
    Connections {
        target: root.backend
        function onPackage_details_ready(json) {
            try { root.details = JSON.parse(json) } catch(e) { root.details = null }
            root.detailLoading = false
        }
    }

    function sourceColor() {
        if (!root.pkg) return Theme.accent
        switch (root.pkg.source) {
            case "flatpak": return Theme.flatpakClr
            case "pacman":  return Theme.pacmanClr
            case "aur":     return Theme.aurClr
            default:        return Theme.accent
        }
    }

    // ── Header ────────────────────────────────────────────────────────────────
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 80
        color: Theme.surface
        z: 1

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
            height: 1; color: Theme.border; opacity: 0.6
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 28; anchors.rightMargin: 24
            spacing: 14

            // Back
            Rectangle {
                width: 36; height: 36; radius: Theme.radiusSm
                color: backHov.hovered ? Theme.card : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                Text { anchors.centerIn: parent; text: "←"; color: Theme.textSec; font.pixelSize: 18 }
                HoverHandler { id: backHov }
                TapHandler { onTapped: root.closed() }
            }

            // Icon
            Rectangle {
                width: 48; height: 48; radius: 12
                color: Qt.rgba(root.sourceColor().r, root.sourceColor().g, root.sourceColor().b, 0.12)

                Image {
                    id: headerIcon
                    anchors.fill: parent; anchors.margins: 5
                    source: root.pkg ? (root.pkg.icon || "") : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true; mipmap: true
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    text: root.pkg && root.pkg.name ? root.pkg.name[0].toUpperCase() : "?"
                    font.pixelSize: 22; font.bold: true
                    visible: root.pkg && (root.pkg.icon === "" || headerIcon.status !== Image.Ready)
                    color: root.sourceColor()
                }
            }

            // Name + badges
            Column {
                Layout.fillWidth: true
                spacing: 5

                Text {
                    text: root.details ? root.details.name : (root.pkg ? root.pkg.name : "")
                    color: Theme.textPri
                    font.pixelSize: Theme.fontXl
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width
                }

                Row {
                    spacing: 6

                    Rectangle {
                        height: 18; radius: 4
                        width: srcBadge.implicitWidth + 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.rgba(root.sourceColor().r, root.sourceColor().g, root.sourceColor().b, 0.15)
                        Text {
                            id: srcBadge
                            anchors.centerIn: parent
                            text: root.pkg ? root.pkg.source.toUpperCase() : ""
                            font.pixelSize: 10; font.bold: true
                            color: root.sourceColor()
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            var v = root.details ? root.details.version : (root.pkg ? root.pkg.version : "")
                            return v ? "v" + v : ""
                        }
                        font.pixelSize: Theme.fontSm
                        color: Theme.textSec
                        visible: text.length > 0
                    }
                }
            }

            // Install target toggle (flatpak, not installed)
            Row {
                visible: root.pkg && root.pkg.source === "flatpak" && !root.pkg.installed
                spacing: 2

                Repeater {
                    model: [{label:"Sys",value:"system"},{label:"User",value:"user"}]
                    delegate: Rectangle {
                        property bool active: root.flatpakTarget === modelData.value
                        width: 38; height: 28; radius: Theme.radiusSm
                        color: active ? Theme.flatpakClr : Theme.card
                        border.color: Theme.flatpakClr; border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent; text: modelData.label
                            font.pixelSize: 10; font.bold: true
                            color: active ? "white" : Theme.flatpakClr
                        }
                        TapHandler { onTapped: root.flatpakTarget = modelData.value }
                    }
                }
            }

            // Install / Remove button
            ActionButton {
                visible: root.pkg !== null
                label: root.pkg && root.pkg.installed ? "Remove" : "Install"
                btnColor: root.pkg && root.pkg.installed ? Theme.danger : Theme.accent
                onClicked: {
                    if (root.pkg.installed) {
                        root.removeRequested()
                    } else {
                        var src = root.pkg.source === "flatpak"
                            ? "flatpak-" + root.flatpakTarget
                            : root.pkg.source
                        root.installRequested(src)
                    }
                }
            }
        }
    }

    // ── Body ──────────────────────────────────────────────────────────────────
    Item {
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        // Loading spinner
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16
            visible: root.detailLoading

            LoadingSpinner { size: 40; color: Theme.accent; Layout.alignment: Qt.AlignHCenter }
            Text {
                text: "Loading details…"
                color: Theme.textSec; font.pixelSize: Theme.fontMd
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // Scrollable content
        ScrollView {
            anchors.fill: parent
            contentWidth: availableWidth
            clip: true
            visible: !root.detailLoading

            Column {
                width: parent.width
                topPadding: 8
                bottomPadding: 48
                spacing: 0

                // ── Screenshots ───────────────────────────────────────────────
                Column {
                    width: parent.width
                    visible: root.details && root.details.screenshots && root.details.screenshots.length > 0
                    spacing: 0

                    Item { height: 24 }

                    Text {
                        text: "Screenshots"
                        color: Theme.textPri; font.pixelSize: Theme.fontLg; font.bold: true
                        leftPadding: 28
                    }

                    Item { height: 14 }

                    ListView {
                        id: screenshotList
                        width: parent.width
                        height: 200
                        leftMargin: 28; rightMargin: 28
                        orientation: ListView.Horizontal
                        spacing: 12
                        clip: true
                        model: root.details ? root.details.screenshots : []

                        delegate: Rectangle {
                            required property string modelData
                            height: 190
                            width: Math.round(height * 16 / 9)
                            radius: Theme.radiusMd
                            color: Theme.card
                            clip: true

                            Image {
                                id: ssImg
                                anchors.fill: parent
                                source: modelData
                                fillMode: Image.PreserveAspectCrop
                                smooth: true; mipmap: true
                            }

                            Rectangle {
                                anchors.fill: parent; radius: parent.radius
                                color: Theme.card
                                visible: ssImg.status !== Image.Ready
                                Text {
                                    anchors.centerIn: parent
                                    text: "🖼"
                                    font.pixelSize: 28
                                    opacity: 0.3
                                }
                            }

                            Rectangle {
                                anchors.fill: parent; radius: parent.radius
                                color: "#20ffffff"
                                visible: ssHov.hovered && ssImg.status === Image.Ready
                            }

                            HoverHandler { id: ssHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    root.lightboxUrl = modelData
                                    root.showLightbox = true
                                }
                            }
                        }

                        ScrollBar.horizontal: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                implicitHeight: 4; radius: 2
                                color: Theme.accent; opacity: 0.6
                            }
                        }
                    }

                    Item { height: 28 }
                    Rectangle { width: parent.width; height: 1; color: Theme.border; opacity: 0.35 }
                }

                // ── About ─────────────────────────────────────────────────────
                Column {
                    width: parent.width
                    visible: root.details && root.details.description.length > 0
                    spacing: 0

                    Item { height: 28 }

                    Text {
                        text: "About"
                        color: Theme.textPri; font.pixelSize: Theme.fontLg; font.bold: true
                        leftPadding: 28
                    }

                    Item { height: 12 }

                    Text {
                        x: 28; width: parent.width - 56
                        text: root.details ? root.details.description : ""
                        color: Theme.textSec
                        font.pixelSize: Theme.fontMd
                        wrapMode: Text.WordWrap
                        lineHeight: 1.55
                    }

                    Item { height: 28 }
                    Rectangle { width: parent.width; height: 1; color: Theme.border; opacity: 0.35 }
                }

                // ── Information ───────────────────────────────────────────────
                Column {
                    width: parent.width
                    spacing: 0

                    Item { height: 28 }

                    Text {
                        text: "Information"
                        color: Theme.textPri; font.pixelSize: Theme.fontLg; font.bold: true
                        leftPadding: 28
                    }

                    Item { height: 16 }

                    // Metadata grid (2-column rows)
                    Column {
                        x: 28; width: parent.width - 56
                        spacing: 20

                        component MetaRow: Row {
                            property string lLabel: ""
                            property string lValue: "—"
                            property string rLabel: ""
                            property string rValue: "—"
                            spacing: 0; width: parent.width

                            Column {
                                spacing: 3; width: parent.width / 2
                                Text { text: lLabel; color: Theme.textSec; font.pixelSize: Theme.fontSm }
                                Text {
                                    text: lValue || "—"; color: Theme.textPri
                                    font.pixelSize: Theme.fontMd; font.weight: Font.Medium
                                    width: parent.width - 48; elide: Text.ElideRight
                                }
                            }
                            Column {
                                spacing: 3; width: parent.width / 2
                                visible: rLabel.length > 0
                                Text { text: rLabel; color: Theme.textSec; font.pixelSize: Theme.fontSm }
                                Text {
                                    text: rValue || "—"; color: Theme.textPri
                                    font.pixelSize: Theme.fontMd; font.weight: Font.Medium
                                    width: parent.width - 48; elide: Text.ElideRight
                                }
                            }
                        }

                        MetaRow {
                            lLabel: "Version"
                            lValue: root.details ? root.details.version : (root.pkg ? root.pkg.version : "")
                            rLabel: "Source"
                            rValue: root.pkg ? root.pkg.source : ""
                        }
                        MetaRow {
                            lLabel: "Developer"
                            lValue: root.details ? root.details.developer : ""
                            rLabel: "License"
                            rValue: root.details ? root.details.license : ""
                        }
                        MetaRow {
                            lLabel: "Installed Size"
                            lValue: root.details ? root.details.size : (root.pkg ? root.pkg.size : "")
                            rLabel: "Last Updated"
                            rValue: root.details ? root.details.last_updated : ""
                        }
                    }

                    // Homepage link
                    Column {
                        visible: root.details && root.details.homepage.length > 0
                        x: 28; width: parent.width - 56
                        topPadding: 20
                        bottomPadding: 4
                        spacing: 3

                        Text { text: "Homepage"; color: Theme.textSec; font.pixelSize: Theme.fontSm }
                        Text {
                            text: root.details ? root.details.homepage : ""
                            color: Theme.accent; font.pixelSize: Theme.fontMd
                            font.weight: Font.Medium
                            width: parent.width; elide: Text.ElideRight
                            HoverHandler { id: linkHov; cursorShape: Qt.PointingHandCursor }
                            opacity: linkHov.hovered ? 0.7 : 1.0
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                            TapHandler {
                                onTapped: if (root.details) Qt.openUrlExternally(root.details.homepage)
                            }
                        }
                    }

                    Item { height: 28 }
                    Rectangle {
                        width: parent.width; height: 1; color: Theme.border; opacity: 0.35
                        visible: root.details && root.details.changelog && root.details.changelog.length > 0
                    }
                }

                // ── Release History ───────────────────────────────────────────
                Column {
                    width: parent.width
                    visible: root.details && root.details.changelog && root.details.changelog.length > 0
                    spacing: 10

                    Item { height: 18 }

                    Text {
                        text: "Release History"
                        color: Theme.textPri; font.pixelSize: Theme.fontLg; font.bold: true
                        leftPadding: 28
                    }

                    Item { height: 4 }

                    Repeater {
                        model: root.details ? root.details.changelog : []

                        delegate: Rectangle {
                            required property var modelData
                            x: 28; width: parent.width - 56
                            radius: Theme.radiusMd
                            color: Theme.card
                            height: entryCol.implicitHeight + 28

                            // Left accent bar
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top; anchors.bottom: parent.bottom
                                anchors.topMargin: 10; anchors.bottomMargin: 10
                                width: 3; radius: 2
                                color: Theme.accent; opacity: 0.6
                            }

                            Column {
                                id: entryCol
                                anchors.left: parent.left; anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.leftMargin: 18; anchors.rightMargin: 18
                                anchors.topMargin: 14
                                spacing: 6

                                RowLayout {
                                    width: parent.width
                                    Text {
                                        text: "v" + modelData.version
                                        color: Theme.textPri
                                        font.pixelSize: Theme.fontMd; font.bold: true
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: modelData.date
                                        color: Theme.textSec; font.pixelSize: Theme.fontSm
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.description || "Bug fixes and improvements."
                                    color: Theme.textSec; font.pixelSize: Theme.fontSm
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.4
                                    visible: text.length > 0
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Screenshot lightbox ───────────────────────────────────────────────────
    Rectangle {
        id: lightbox
        anchors.fill: parent
        z: 100
        color: "#dd000000"
        visible: opacity > 0
        opacity: root.showLightbox ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        // Absorbs ALL pointer events — nothing below fires when lightbox is visible
        MouseArea {
            anchors.fill: parent
            onClicked: root.showLightbox = false
        }

        Image {
            id: lightboxImg
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, (parent.height - 120) * 16 / 9)
            height: width * 9 / 16
            source: root.lightboxUrl
            fillMode: Image.PreserveAspectFit
            smooth: true; mipmap: true

            Rectangle {
                anchors.fill: parent; anchors.margins: -1
                color: "transparent"
                border.color: "#30ffffff"; border.width: 1
                radius: Theme.radiusMd
                z: -1
            }

            // Close button anchored just outside the image's top-right corner,
            // well away from the page header where Remove lives
            Rectangle {
                anchors.left: parent.right; anchors.top: parent.top
                anchors.leftMargin: 10
                width: 36; height: 36; radius: 18
                color: lbCloseHov.hovered ? "#80ffffff" : "#50000000"
                border.color: "#50ffffff"; border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                Text { anchors.centerIn: parent; text: "✕"; color: "white"; font.pixelSize: 14; font.bold: true }
                HoverHandler { id: lbCloseHov; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: root.showLightbox = false }
            }
        }
    }
}
