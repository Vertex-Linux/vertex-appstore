import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import VertexStore

Rectangle {
    id: root
    width: 220
    color: Theme.sidebar

    property int currentIndex: 0
    property int activeTasks: 0   // queued + running
    property int totalTasks: 0    // all tasks including done/failed

    signal queueClicked

    // Right border separator
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Theme.border
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Brand header
        Rectangle {
            Layout.fillWidth: true
            height: 72
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 16
                spacing: 12

                Rectangle {
                    width: 36; height: 36; radius: 10
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.accent }
                        GradientStop { position: 1.0; color: Qt.lighter(Theme.accent, 1.3) }
                    }
                    Text { anchors.centerIn: parent; text: "V"; color: "white"; font.pixelSize: 20; font.bold: true }
                }

                Column {
                    spacing: 2
                    Text { text: "Vertex Store"; color: Theme.textPri; font.pixelSize: Theme.fontLg; font.bold: true }
                    Text { text: "Package Manager"; color: Theme.textSec; font.pixelSize: Theme.fontSm }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; opacity: 0.6 }
        Item { height: 12 }

        NavItem { Layout.fillWidth: true; icon: "⌂"; label: "Home";      selected: root.currentIndex === 0; onClicked: root.currentIndex = 0 }
        NavItem { Layout.fillWidth: true; icon: "▦"; label: "Installed";  selected: root.currentIndex === 1; onClicked: root.currentIndex = 1 }
        NavItem { Layout.fillWidth: true; icon: "↑"; label: "Updates";    selected: root.currentIndex === 2; onClicked: root.currentIndex = 2 }
        NavItem { Layout.fillWidth: true; icon: "⌕"; label: "Search";     selected: root.currentIndex === 3; onClicked: root.currentIndex = 3 }

        Item { Layout.fillHeight: true }

        // ── Task queue indicator ────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 50
            visible: root.totalTasks > 0
            clip: true
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.topMargin: 2
                anchors.bottomMargin: 2
                radius: Theme.radiusSm
                color: queueHov.containsMouse ? Theme.surface : "transparent"

                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 10

                    // Spinning icon when active, checkmark when all done
                    Item {
                        width: 18; height: 18

                        Text {
                            anchors.centerIn: parent
                            text: root.activeTasks > 0 ? "↻" : "✓"
                            color: root.activeTasks > 0 ? Theme.warning : Theme.success
                            font.pixelSize: 16
                            font.bold: root.activeTasks === 0

                            RotationAnimator on rotation {
                                from: 0; to: 360
                                duration: 1000
                                loops: Animation.Infinite
                                running: root.activeTasks > 0
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.activeTasks > 0
                            ? root.activeTasks + " task" + (root.activeTasks === 1 ? "" : "s") + " running"
                            : "Tasks"
                        color: root.activeTasks > 0 ? Theme.warning : Theme.textSec
                        font.pixelSize: Theme.fontMd
                        font.weight: root.activeTasks > 0 ? Font.Medium : Font.Normal
                        elide: Text.ElideRight
                    }

                    // Badge
                    Rectangle {
                        visible: root.activeTasks > 0
                        width: Math.max(22, badgeNum.implicitWidth + 8)
                        height: 20
                        radius: 10
                        color: Theme.warning

                        Text {
                            id: badgeNum
                            anchors.centerIn: parent
                            text: root.activeTasks
                            color: "white"
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }

                HoverHandler { id: queueHov }
                TapHandler { onTapped: root.queueClicked() }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; opacity: 0.6 }
        Item { height: 8 }

        NavItem {
            Layout.fillWidth: true
            icon: "⚙"
            label: "Settings"
            selected: root.currentIndex === 4
            onClicked: root.currentIndex = 4
        }

        Item { height: 12 }
    }

    component NavItem: Rectangle {
        property string icon: ""
        property string label: ""
        property bool selected: false
        signal clicked

        height: 46
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 10; anchors.rightMargin: 10
            anchors.topMargin: 2;   anchors.bottomMargin: 2
            radius: Theme.radiusSm
            color: selected ? Theme.accent : (hov.containsMouse ? Theme.surface : "transparent")
            opacity: selected ? 1.0 : (hov.containsMouse ? 0.7 : 1.0)
            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14; anchors.rightMargin: 14
                spacing: 12

                Text {
                    text: icon
                    color: selected ? "white" : Theme.textSec
                    font.pixelSize: 16
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                Text {
                    Layout.fillWidth: true
                    text: label
                    color: selected ? "white" : Theme.textSec
                    font.pixelSize: Theme.fontMd
                    font.weight: selected ? Font.Medium : Font.Normal
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
        }

        HoverHandler { id: hov }
        TapHandler { onTapped: parent.clicked() }
        Behavior on height { NumberAnimation { duration: 120 } }
    }
}
