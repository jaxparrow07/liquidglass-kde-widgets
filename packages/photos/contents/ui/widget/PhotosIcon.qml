import QtQuick

// The Photos app tile shown in the empty state: a rounded tile holding an
// eight-petal flower. Colored in solid; monochrome white in glass.
Item {
    id: icon

    property QtObject styleColors
    property real size: 64

    width: size
    height: size

    Rectangle {
        anchors.fill: parent
        radius: width * 0.225
        border.width: Math.max(1, Math.round(icon.size / 64))
        border.color: icon.styleColors.photosIconTileBorder
        gradient: Gradient {
            GradientStop { position: 0.0; color: icon.styleColors.photosIconTileTop }
            GradientStop { position: 1.0; color: icon.styleColors.photosIconTileBottom }
        }
    }

    Canvas {
        id: flower
        anchors.fill: parent
        anchors.margins: icon.size * 0.075
        antialiasing: true

        readonly property bool mono: icon.styleColors.photosIconMonochrome
        onMonoChanged: requestPaint()
        onWidthChanged: requestPaint()

        // Clockwise from the top petal, as on the macOS Photos icon.
        readonly property var petalColors: [
            "#f98a16", "#f9c80e", "#8fcf2a", "#2dbf6c",
            "#2f7cf6", "#8a52e8", "#e8459b", "#f0453a"
        ]

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var s = width
            var c = s / 2
            // Wide oval petals whose inner ends meet around a hole.
            var rx = s * 0.15   // half width
            var ry = s * 0.225  // half length
            var d = s * 0.27   // petal center distance from the middle
            for (var i = 0; i < 8; i++) {
                ctx.save()
                ctx.translate(c, c)
                ctx.rotate(i * Math.PI / 4)
                ctx.globalAlpha = mono ? 0.28 : 0.9
                ctx.fillStyle = mono ? "#ffffff" : petalColors[i]
                ctx.beginPath()
                ctx.ellipse(-rx, -d - ry, rx * 2, ry * 2)
                ctx.fill()
                ctx.restore()
            }
            // Punch the hole in the middle (shows the tile through it).
            ctx.globalAlpha = 1
            ctx.globalCompositeOperation = "destination-out"
            ctx.beginPath()
            ctx.arc(c, c, s * 0.075, 0, 2 * Math.PI)
            ctx.fill()
            ctx.globalCompositeOperation = "source-over"
        }
    }
}
