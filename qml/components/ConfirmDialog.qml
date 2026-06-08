import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import VertexStore

Item {
    id: root

    property string title: ""
    property string message: ""
    property string confirmLabel: "Confirm"
    property bool   destructive: true   // red confirm button vs accent

    signal accepted
    signal rejected

    // Semi-transparent backdrop
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)

        // Click outside to cancel
        TapHandler { onTapped: root.rejected() }

        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    // Dialog card
    Rectangle {
        anchors.centerIn: parent
        width: 400
        height: content.implicitHeight + 56
        radius: Theme.radiusMd
        color: Theme.surface

        layer.enabled: true
        layer.effect: null

        // Absorb clicks so they don't reach the backdrop dismiss handler
        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 28
            anchors.leftMargin: 28
            anchors.rightMargin: 28
            spacing: 12

            Text {
                text: root.title
                color: Theme.textPri
                font.pixelSize: Theme.fontLg
                font.bold: true
                width: parent.width
                wrapMode: Text.WordWrap
            }

            Text {
                text: root.message
                color: Theme.textSec
                font.pixelSize: Theme.fontMd
                width: parent.width
                wrapMode: Text.WordWrap
                lineHeight: 1.4
            }

            Item { height: 8 }

            RowLayout {
                width: parent.width
                spacing: 10

                Item { Layout.fillWidth: true }

                ActionButton {
                    label: "Cancel"
                    outlined: true
                    onClicked: root.rejected()
                }

                ActionButton {
                    label: root.confirmLabel
                    btnColor: root.destructive ? Theme.danger : Theme.accent
                    onClicked: root.accepted()
                }
            }

            Item { height: 4 }
        }
    }

    // Fade in
    NumberAnimation on opacity {
        from: 0; to: 1; duration: 150
        running: true
    }
}
