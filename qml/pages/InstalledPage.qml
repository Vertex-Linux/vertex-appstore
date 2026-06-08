import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import VertexStore

Item {
    id: root
    property var backend
    property var confirmFn: null
    property var openDetail: null
    property var packages: []
    property string filterSource: "all"

    function refresh() {
        backend.get_installed()
    }

    function loadPackages(json) {
        try {
            packages = JSON.parse(json)
        } catch(e) {
            packages = []
        }
    }

    property var filteredPackages: {
        if (filterSource === "all") return packages
        return packages.filter(p => p.source === filterSource)
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
                    text: "Installed"
                    color: Theme.textPri
                    font.pixelSize: Theme.fontXxl
                    font.bold: true
                }

                Text {
                    text: root.filteredPackages.length + " packages"
                    color: Theme.textSec
                    font.pixelSize: Theme.fontMd
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                ActionButton {
                    label: "Refresh"
                    icon: "↺"
                    outlined: true
                    onClicked: root.refresh()
                }
            }
        }

        // Source filter tabs
        Rectangle {
            width: parent.width
            height: 46
            color: Theme.bg

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: [
                        { label: "All",     key: "all"     },
                        { label: "Flatpak", key: "flatpak" },
                        { label: "Pacman",  key: "pacman"  }
                    ]

                    Rectangle {
                        height: 30
                        width: tabLabel.implicitWidth + 20
                        radius: Theme.radiusSm
                        color: root.filterSource === modelData.key ? Theme.accent : Theme.card

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            id: tabLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: Theme.fontSm
                            font.weight: root.filterSource === modelData.key ? Font.Medium : Font.Normal
                            color: root.filterSource === modelData.key ? "white" : Theme.textSec

                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        TapHandler { onTapped: root.filterSource = modelData.key }
                    }
                }
            }
        }

        // List
        Item {
            width: parent.width
            height: parent.height - 118

            EmptyState {
                anchors.fill: parent
                visible: root.filteredPackages.length === 0 && !backend.is_loading
                icon: "▦"
                title: "No packages installed"
                subtitle: "Click Refresh to load"
            }

            ListView {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                anchors.topMargin: 8
                clip: true
                spacing: 8
                model: root.filteredPackages
                visible: root.filteredPackages.length > 0

                ScrollBar.vertical: ScrollBar {
                    contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.accent; opacity: 0.6 }
                }

                delegate: PackageCard {
                    width: ListView.view.width
                    pkgName:      modelData.name
                    pkgDesc:      modelData.description
                    pkgVersion:   modelData.version
                    pkgSource:    modelData.source
                    pkgInstalled: true
                    pkgIcon:      modelData.icon || ""

                    onCardClicked: { if (root.openDetail) root.openDetail(modelData) }
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
