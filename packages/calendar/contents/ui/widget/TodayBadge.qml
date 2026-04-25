import QtQuick

// Filled active-date circle. In glass mode, the day number is punched
// out so the backdrop shows through; in solid mode, the number is drawn
// normally over the badge.
Item {
    id: root

    property int dayNumber: 1
    property real diameter: 40
    property real circleXOffset: 0
    property real circleYOffset: 0
    property real fontPixelSize: 12
    property color badgeColor: "#ff3b30"
    property color textColor: "#ffffff"
    property string fontFamily: ""
    property bool punchOutText: true
    property rect contentRect: Qt.rect(0, 0, width, height)

    onDayNumberChanged: canvas.requestPaint()
    onBadgeColorChanged: canvas.requestPaint()
    onTextColorChanged: canvas.requestPaint()
    onFontFamilyChanged: canvas.requestPaint()
    onDiameterChanged: canvas.requestPaint()
    onCircleXOffsetChanged: canvas.requestPaint()
    onCircleYOffsetChanged: canvas.requestPaint()
    onFontPixelSizeChanged: canvas.requestPaint()
    onPunchOutTextChanged: canvas.requestPaint()
    onContentRectChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            const textCx = root.contentRect.x + root.contentRect.width / 2;
            const textCy = root.contentRect.y + root.contentRect.height / 2;
            const circleCx = textCx + root.circleXOffset;
            const circleCy = textCy + root.circleYOffset;
            const r = root.diameter / 2;

            // 1. Filled circle.
            ctx.fillStyle = root.badgeColor;
            ctx.beginPath();
            ctx.arc(circleCx, circleCy, r, 0, Math.PI * 2);
            ctx.closePath();
            ctx.fill();

            const px = Math.round(root.fontPixelSize);
            ctx.font = "400 " + px + "px \"" + root.fontFamily + "\"";
            ctx.textAlign = "center";
            ctx.textBaseline = "alphabetic";

            if (root.punchOutText) {
                // "destination-out" keeps existing pixels only where the
                // new shape is NOT drawn, so the digit becomes transparent.
                ctx.globalCompositeOperation = "destination-out";
                ctx.fillStyle = "#ffffff"; // color doesn't matter, only alpha
            } else {
                ctx.globalCompositeOperation = "source-over";
                ctx.fillStyle = root.textColor;
            }

            const text = String(root.dayNumber);
            const metrics = ctx.measureText(text);
            const ascent = metrics.actualBoundingBoxAscent || px * 0.72;
            const descent = metrics.actualBoundingBoxDescent || px * 0.20;
            const baselineY = textCy + (ascent - descent) / 2;
            ctx.fillText(text, textCx, baselineY);

            ctx.globalCompositeOperation = "source-over";
        }
    }
}
