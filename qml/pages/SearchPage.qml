import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import VertexStore

Item {
    id: root
    property var backend
    property var confirmFn: null
    property var openDetail: null

    property var results: []
    property bool hasSearched: false

    function startSearch(query) {
        searchField.text = query
        doSearch(query)
    }

    function loadResults(json) {
        try {
            results = JSON.parse(json)
        } catch(e) {
            results = []
        }
    }

    function doSearch(query) {
        if (query.trim().length === 0) return
        results = []
        hasSearched = true
        backend.search(query)
    }

    Column {
        anchors.fill: parent
        spacing: 0

        // Top bar
        Rectangle {
            width: parent.width
            height: 72
            color: Theme.surface

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 28
                anchors.rightMargin: 28
                spacing: 14

                Text {
                    text: "Search"
                    color: Theme.textPri
                    font.pixelSize: Theme.fontXxl
                    font.bold: true
                }

                // Search field
                Rectangle {
                    Layout.fillWidth: true
                    height: 42
                    radius: Theme.radiusMd
                    color: Theme.card
                    border.color: searchField.activeFocus ? Theme.accent : Theme.border
                    border.width: searchField.activeFocus ? 2 : 1

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: "⌕"
                            color: searchField.activeFocus ? Theme.accent : Theme.textSec
                            font.pixelSize: 16
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        TextInput {
                            id: searchField
                            Layout.fillWidth: true
                            color: Theme.textPri
                            font.pixelSize: Theme.fontMd
                            selectByMouse: true

                            property string placeholder: "Search Flatpak, Pacman and AUR..."

                            Keys.onReturnPressed: root.doSearch(text)

                            Text {
                                visible: searchField.text.length === 0
                                text: searchField.placeholder
                                color: Theme.textSec
                                font: searchField.font
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Clear button
                        Rectangle {
                            width: 22; height: 22; radius: 11
                            color: Theme.textSec
                            opacity: searchField.text.length > 0 ? 0.4 : 0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: 11
                                color: Theme.bg
                                font.bold: true
                            }
                            TapHandler { onTapped: { searchField.text = ""; root.results = []; root.hasSearched = false } }
                        }
                    }
                }

                ActionButton {
                    label: "Search"
                    icon: "⌕"
                    onClicked: root.doSearch(searchField.text)
                }
            }
        }

        // Result count / hint
        Rectangle {
            width: parent.width
            height: 38
            color: Theme.bg

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 28
                anchors.rightMargin: 28

                Text {
                    text: root.results.length > 0
                        ? root.results.length + " results"
                        : (searchField.text.length > 0 ? "No results" : "Type to search")
                    color: Theme.textSec
                    font.pixelSize: Theme.fontSm
                }

                Item { Layout.fillWidth: true }

                // Source filter chips
                Row {
                    spacing: 6

                    Repeater {
                        model: [
                            { label: "Flatpak", key: "flatpak", color: Theme.flatpakClr },
                            { label: "Pacman",  key: "pacman",  color: Theme.pacmanClr  },
                            { label: "AUR",     key: "aur",     color: Theme.aurClr     }
                        ]

                        Rectangle {
                            height: 24
                            width: filterText.implicitWidth + 16
                            radius: 12
                            color: filterActive ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.2) : Theme.card
                            border.color: modelData.color
                            border.width: filterActive ? 0 : 1

                            property bool filterActive: {
                                if (modelData.key === "flatpak") return backend.show_flatpak
                                if (modelData.key === "pacman")  return backend.show_pacman
                                return backend.show_aur
                            }

                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                id: filterText
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: 11
                                font.bold: true
                                color: modelData.color
                            }
                            TapHandler {
                                onTapped: {
                                    backend.toggle_source(modelData.key, !filterActive)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Results list
        Item {
            width: parent.width
            height: parent.height - 110

            EmptyState {
                anchors.fill: parent
                visible: root.results.length === 0 && !backend.is_loading
                icon: root.hasSearched ? "◎" : "⌕"
                title: root.hasSearched ? "No results found" : "Search for packages"
                subtitle: root.hasSearched ? "Try a different query" : "Flatpak, Pacman and AUR"
            }

            ListView {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                anchors.topMargin: 8
                clip: true
                spacing: 8
                visible: root.results.length > 0
                model: root.results

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: Theme.accent
                        opacity: 0.6
                    }
                }

                delegate: PackageCard {
                    width: ListView.view.width
                    pkgName:      modelData.name
                    pkgDesc:      modelData.description
                    pkgVersion:   modelData.version
                    pkgSource:    modelData.source
                    pkgInstalled: modelData.installed
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

                add:    Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 } }
                remove: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150 } }
            }
        }
    }
}
