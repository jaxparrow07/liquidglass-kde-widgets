import QtQuick

// White squircle on transparent, matching LiquidGlass's silhouette, for use
// as a MultiEffect maskSource. Same corner math as the music widget's art mask.
Item {
    id: mask

    property real cornerRadius: 100
    property real roundness: 7.5

    layer.enabled: true
    visible: false

    onCornerRadiusChanged: canvas.requestPaint()
    onRoundnessChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var w = width, h = height
            var r = Math.min(mask.cornerRadius, w / 2, h / 2)
            var n = Math.max(mask.roundness, 2.0)
            var steps = 32

            function cornerX(t) { return r * Math.pow(Math.abs(Math.cos(t)), 2.0 / n) }
            function cornerY(t) { return r * Math.pow(Math.abs(Math.sin(t)), 2.0 / n) }

            ctx.beginPath()
            ctx.moveTo(r, 0)
            ctx.lineTo(w - r, 0)
            for (var i = 1; i <= steps; i++) {
                var t = (1 - i / steps) * Math.PI / 2
                ctx.lineTo(w - r + cornerX(t), r - cornerY(t))
            }
            ctx.lineTo(w, h - r)
            for (var j = 1; j <= steps; j++) {
                var t2 = (1 - j / steps) * Math.PI / 2
                ctx.lineTo(w - r + cornerY(t2), h - r + cornerX(t2))
            }
            ctx.lineTo(r, h)
            for (var k = 1; k <= steps; k++) {
                var t3 = (1 - k / steps) * Math.PI / 2
                ctx.lineTo(r - cornerX(t3), h - r + cornerY(t3))
            }
            ctx.lineTo(0, r)
            for (var m = 1; m <= steps; m++) {
                var t4 = (1 - m / steps) * Math.PI / 2
                ctx.lineTo(r - cornerY(t4), r - cornerX(t4))
            }
            ctx.closePath()
            ctx.fillStyle = "white"
            ctx.fill()
        }
    }
}
