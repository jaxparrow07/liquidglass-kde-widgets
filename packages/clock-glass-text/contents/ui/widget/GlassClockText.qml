import QtQuick

// The clock typography: a small day label stacked above big HH:MM digits,
// all in one font. Used twice by main.qml —
//   1. as the off-screen MASK for TextGlass (white glyphs on transparent),
//   2. as the faint, legible overlay text drawn on top of the glass.
// Both instances share identical geometry so the overlay lines up exactly
// with the refracting glass glyphs underneath.
Item {
    id: root

    property int hour12: 12       // 1..12
    property int minute: 0        // 0..59
    property string dayText: ""   // e.g. "MONDAY"

    property real fontPixelSize: 96
    property real availableWidth: 0   // 0 disables auto-shrink

    property color glyphColor: "#ffffff"
    property real glyphOpacity: 1.0
    // Main font for the HH:MM digits (user-selectable).
    property string fontFamily: ""
    // Font for the day/date label — kept fixed regardless of the digit font.
    // Falls back to the digit font if not set.
    property string dayFontFamily: ""
    readonly property string _dayFont: dayFontFamily.length > 0 ? dayFontFamily : fontFamily

    // Day label is a fraction of the big digits.
    readonly property real _dayFontSize: _effectiveFontSize * 0.22
    readonly property real _letterSpacing: -_effectiveFontSize * 0.02
    readonly property real _gap: _effectiveFontSize * 0.10
    readonly property real _dotDiameter: Math.max(3, Math.round(_effectiveFontSize * 0.11))

    TextMetrics {
        id: hourMetrics
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.letterSpacing: -root.fontPixelSize * 0.02
        text: String(root.hour12)
    }
    TextMetrics {
        id: minMetrics
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.letterSpacing: -root.fontPixelSize * 0.02
        text: root.minute < 10 ? "0" + root.minute : String(root.minute)
    }

    readonly property real _naturalWidth:
        hourMetrics.width + minMetrics.width
        + Math.max(3, Math.round(fontPixelSize * 0.11))
        + 2 * (fontPixelSize * 0.10)
    readonly property real _scale:
        (availableWidth > 0 && _naturalWidth > availableWidth)
            ? availableWidth / _naturalWidth
            : 1
    readonly property real _effectiveFontSize: fontPixelSize * _scale

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Column {
        id: column
        anchors.centerIn: parent
        spacing: root._effectiveFontSize * 0.04

        Text {
            id: dayLabel
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.dayText
            visible: text.length > 0
            color: root.glyphColor
            opacity: root.glyphOpacity
            font.family: root._dayFont
            font.pixelSize: root._dayFontSize
            font.letterSpacing: -root._dayFontSize * 0.01
            renderType: Text.NativeRendering
        }

        Row {
            id: timeRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root._gap

            Text {
                id: hourText
                anchors.verticalCenter: parent.verticalCenter
                text: root.hour12
                color: root.glyphColor
                opacity: root.glyphOpacity
                font.family: root.fontFamily
                font.pixelSize: root._effectiveFontSize
                font.letterSpacing: root._letterSpacing
                renderType: Text.NativeRendering
            }

            Item {
                id: dotHolder
                width: root._dotDiameter
                height: hourText.height
                anchors.verticalCenter: parent.verticalCenter

                Column {
                    anchors.centerIn: parent
                    spacing: root._dotDiameter * 1.4

                    Rectangle {
                        width: root._dotDiameter; height: root._dotDiameter
                        radius: root._dotDiameter / 2
                        color: root.glyphColor; opacity: root.glyphOpacity
                        antialiasing: true
                    }
                    Rectangle {
                        width: root._dotDiameter; height: root._dotDiameter
                        radius: root._dotDiameter / 2
                        color: root.glyphColor; opacity: root.glyphOpacity
                        antialiasing: true
                    }
                }
            }

            Text {
                id: minText
                anchors.verticalCenter: parent.verticalCenter
                text: root.minute < 10 ? "0" + root.minute : root.minute
                color: root.glyphColor
                opacity: root.glyphOpacity
                font.family: root.fontFamily
                font.pixelSize: root._effectiveFontSize
                font.letterSpacing: root._letterSpacing
                renderType: Text.NativeRendering
            }
        }
    }
}
