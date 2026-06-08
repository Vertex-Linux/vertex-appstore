import QtQuick
import VertexStore

Rectangle {
    id: root
    property string label: ""
    property string icon: ""
    property color  btnColor: Theme.accent
    property color  textColor: outlined ? root.btnColor : "white"
    property bool   outlined: false

    signal clicked

    height: 38
    width: row.implicitWidth + 32
    radius: Theme.radiusSm
    color: outlined ? "transparent" : (hov.hovered ? Qt.lighter(btnColor, 1.1) : btnColor)
    border.color: outlined ? textColor : "transparent"
    border.width: outlined ? 1 : 0

    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            visible: root.icon.length > 0
            text: root.icon
            color: root.textColor
            font.pixelSize: Theme.fontMd
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.label
            color: root.textColor
            font.pixelSize: Theme.fontMd
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    HoverHandler { id: hov }
    TapHandler { onTapped: root.clicked() }
}
