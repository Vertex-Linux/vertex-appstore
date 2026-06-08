import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import VertexStore

Item {
    id: root
    property var backend
    property var confirmFn: null
    property var openDetail: null
    property var updates: []

    function refresh() {
        backend.get_updates()
    }

    function loadUpdates(json) {
        try {
            updates = JSON.parse(json)
        } catch(e) {
            updates = []
        }
    }

    Column {
        anchors.fill: parent
        spacing: 0

        // Header
        Rectangle {
            width: parent.width
            height: 72
            color: Theme.surface

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 28
                anchors.rightMargin: 28
                spacing: 16

                Text {
                    text: "Updates"
                    color: Theme.textPri
                    font.pixelSize: Theme.fontXxl
                    font.bold: true
                }

                // Badge
                Rectangle {
                    visible: root.updates.length > 0
                    width: Math.max(24, updateBadge.implicitWidth + 10)
                    height: 24
                    radius: 12
                    color: Theme.warning

                    Text {
                        id: updateBadge
                        anchors.centerIn: parent
                        text: root.updates.length
                        color: "white"
                        font.pixelSize: Theme.fontSm
                        font.bold: true
                    }
                }

                Item { Layout.fillWidth: true }

                ActionButton {
                    label: "Refresh"
                    icon: "↺"
                    outlined: true
                    onClicked: root.refresh()
                }

                ActionButton {
                    label: "Update All"
                    icon: "↑"
                    visible: root.updates.length > 0
                    btnColor: Theme.warning
                    onClicked: root.confirmFn(
                        "Update all packages?",
                        "This will update all " + root.updates.length + " available update" + (root.updates.length === 1 ? "" : "s") + " to their latest versions.",
                        function() { backend.update_all() },
                        "Update All",
                        false
                    )
                }
            }
        }

        // Content
        Item {
            width: parent.width
            height: parent.height - 72

            EmptyState {
                anchors.fill: parent
                visible: root.updates.length === 0 && !backend.is_loading
                icon: "✓"
                title: "Everything is up to date"
                subtitle: "Click Refresh to check for updates"
            }

            Column {
                anchors.fill: parent
                visible: root.updates.length > 0
                spacing: 0

                Rectangle {
                    width: parent.width
                    height: 48
                    color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.1)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 28
                        anchors.rightMargin: 28

                        Text {
                            text: "ℹ  " + root.updates.length + " update" + (root.updates.length === 1 ? "" : "s") + " available"
                            color: Theme.warning
                            font.pixelSize: Theme.fontMd
                        }
                        Item { Layout.fillWidth: true }
                    }
                }

                ListView {
                    width: parent.width
                    height: parent.height - 48
                    leftMargin: 24
                    rightMargin: 24
                    topMargin: 8
                    clip: true
                    spacing: 8
                    model: root.updates

                    ScrollBar.vertical: ScrollBar {
                        contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.accent; opacity: 0.6 }
                    }

                    delegate: PackageCard {
                        width: ListView.view.width - 48
                        x: 0
                        pkgName:      modelData.name
                        pkgDesc:      modelData.description
                        pkgVersion:   modelData.version
                        pkgSource:    modelData.source
                        pkgInstalled: true
                        pkgIcon:      modelData.icon || ""

                        onCardClicked: { if (root.openDetail) root.openDetail(modelData) }
                        onInstallClicked: (src) => backend.install_package(modelData.app_id || modelData.name, src)
                        onRemoveClicked: {
                            var id  = modelData.app_id || modelData.name
                            var src = modelData.source
                            var nm  = modelData.name
                            root.confirmFn(
                                "Remove " + nm + "?",
                                "This will uninstall " + nm + " from your system.",
                                function() { backend.remove_package(id, src) }
                            )
                        }
                    }
                }
            }
        }
    }
}
