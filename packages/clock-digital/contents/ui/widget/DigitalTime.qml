import QtQuick

// Condensed HH:MM readout. Layout: a centered Row with three items —
// [hour] [colon-dots] [minute]. The dots live inside an Item whose
// height matches the font's line height so they sit on the glyph
// baseline-ish mid-x-height, vertically centered.
Item {
    id: root

    property int hour12: 12     // 1..12
    property int minute: 0      // 0..59
    // Desired font size. Actual rendered size is `_effectiveFontSize`,
    // which scales down to fit `availableWidth` when the content (hour
    // + colon + minute) would overflow (e.g. 12:45 vs 9:03).
    property real fontPixelSize: 48
    property real availableWidth: 0     // 0 disables auto-shrink
    property real digitOpacity: 0.55
    property color textColor: "#ffffff"
    property string fontFamily: ""

    // Measure the would-be content width at the requested fontPixelSize
    // using a two-digit stand-in for each side (worst case), then scale
    // down so the rendered layout fits `availableWidth` if given.
    TextMetrics {
        id: hourMetrics
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: Font.Medium
        font.letterSpacing: -root.fontPixelSize * 0.03
        text: String(root.hour12)
    }
    TextMetrics {
        id: minMetrics
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: Font.Medium
        font.letterSpacing: -root.fontPixelSize * 0.03
        text: root.minute < 10 ? "0" + root.minute : String(root.minute)
    }

    readonly property real _naturalWidth:
        hourMetrics.width + minMetrics.width
        + Math.max(3, Math.round(fontPixelSize * 0.10))  // dot column width
        + 2 * (fontPixelSize * 0.10)                     // two gaps
    readonly property real _scale:
        (availableWidth > 0 && _naturalWidth > availableWidth)
            ? availableWidth / _naturalWidth
            : 1
    readonly property real _effectiveFontSize: fontPixelSize * _scale

    // Tight letter spacing for the "condensed" look.
    readonly property real _letterSpacing: -_effectiveFontSize * 0.03
    // Gap between digits and colon on each side — small, for a
    // compact cluster.
    readonly property real _gap: _effectiveFontSize * 0.10
    // Dot diameter sized to match the font's stroke thickness so the
    // colon reads as "part of the typeface" rather than a separate
    // shape. Barlow Medium has a stroke ~10% of pixel size.
    readonly property real _dotDiameter: Math.max(3, Math.round(_effectiveFontSize * 0.10))

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Row {
        id: layout
        anchors.centerIn: parent
        spacing: root._gap

        Text {
            id: hourText
            anchors.verticalCenter: parent.verticalCenter
            text: root.hour12
            color: root.textColor
            opacity: root.digitOpacity
            font.family: root.fontFamily
            font.pixelSize: root._effectiveFontSize
            font.weight: Font.Medium
            font.letterSpacing: root._letterSpacing
            renderType: Text.NativeRendering
        }

        // Colon dots. Parent Item's height equals the rendered text
        // height; the two dots are then VERTICALLY CENTERED inside it
        // as a single Column unit (no asymmetric placement).
        Item {
            id: dotHolder
            width: root._dotDiameter
            height: hourText.height
            anchors.verticalCenter: parent.verticalCenter

            Column {
                anchors.centerIn: parent
                spacing: root._dotDiameter * 1.4

                Rectangle {
                    width: root._dotDiameter
                    height: root._dotDiameter
                    radius: root._dotDiameter / 2
                    color: root.textColor
                    opacity: root.digitOpacity
                    antialiasing: true
                }
                Rectangle {
                    width: root._dotDiameter
                    height: root._dotDiameter
                    radius: root._dotDiameter / 2
                    color: root.textColor
                    opacity: root.digitOpacity
                    antialiasing: true
                }
            }
        }

        Text {
            id: minText
            anchors.verticalCenter: parent.verticalCenter
            text: root.minute < 10 ? "0" + root.minute : root.minute
            color: root.textColor
            opacity: root.digitOpacity
            font.family: root.fontFamily
            font.pixelSize: root._effectiveFontSize
            font.weight: Font.Medium
            font.letterSpacing: root._letterSpacing
            renderType: Text.NativeRendering
        }
    }
}
