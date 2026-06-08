import QtQuick
import QtQuick.Layouts
import VertexStore

Item {
    property string icon: "◎"
    property string title: "Nothing here"
    property string subtitle: ""

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 12

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: icon
            font.pixelSize: 52
            color: Theme.textSec
            opacity: 0.4
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: title
            font.pixelSize: Theme.fontXl
            font.weight: Font.Medium
            color: Theme.textSec
            opacity: 0.7
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: subtitle
            font.pixelSize: Theme.fontMd
            color: Theme.textSec
            opacity: 0.5
            visible: subtitle.length > 0
        }
    }
}
