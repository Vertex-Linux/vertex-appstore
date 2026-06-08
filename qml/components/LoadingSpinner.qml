import QtQuick
import VertexStore

Item {
    id: root
    property int size: 32
    property color color: Theme.accent
    width: size
    height: size

    RotationAnimator on rotation {
        from: 0; to: 360
        duration: 900
        loops: Animation.Infinite
        running: root.visible
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var r = width / 2
            ctx.lineWidth = Math.max(3, r * 0.12)
            ctx.lineCap = "round"

            // Background track
            ctx.strokeStyle = Qt.rgba(root.color.r, root.color.g, root.color.b, 0.15)
            ctx.beginPath()
            ctx.arc(r, r, r - ctx.lineWidth / 2, 0, Math.PI * 2)
            ctx.stroke()

            // Spinner arc
            var grad = ctx.createConicalGradient(r, r, 0)
            grad.addColorStop(0,   Qt.rgba(root.color.r, root.color.g, root.color.b, 0))
            grad.addColorStop(0.8, Qt.rgba(root.color.r, root.color.g, root.color.b, 1))
            grad.addColorStop(1,   Qt.rgba(root.color.r, root.color.g, root.color.b, 1))
            ctx.strokeStyle = grad
            ctx.beginPath()
            ctx.arc(r, r, r - ctx.lineWidth / 2, -Math.PI / 2, Math.PI * 1.2)
            ctx.stroke()
        }

        Component.onCompleted: requestPaint()
    }

    onColorChanged: canvas.requestPaint()
}
