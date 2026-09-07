import QtQuick

Item {
    id: root

    property int hour: 12
    property int minute: 0
    property bool use24Hour: false
    property real fontPixelSize: 48
    property real availableWidth: 0
    property real digitOpacity: 0.55
    property color textColor: "#ffffff"
    property string fontFamily: ""

    readonly property string hourText: use24Hour
        ? (hour < 10 ? "0" + hour : String(hour))
        : String(hour)
    readonly property string minuteText: minute < 10 ? "0" + minute : String(minute)

    TextMetrics {
        id: hourMetrics
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: Font.Medium
        font.letterSpacing: -root.fontPixelSize * 0.03
        text: root.hourText
    }
    TextMetrics {
        id: minMetrics
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: Font.Medium
        font.letterSpacing: -root.fontPixelSize * 0.03
        text: root.minuteText
    }

    readonly property real _naturalWidth:
        hourMetrics.width + minMetrics.width
        + Math.max(3, Math.round(fontPixelSize * 0.10))
        + 2 * (fontPixelSize * 0.10)
    readonly property real _scale:
        (availableWidth > 0 && _naturalWidth > availableWidth)
            ? availableWidth / _naturalWidth
            : 1
    readonly property real _effectiveFontSize: fontPixelSize * _scale

    readonly property real _letterSpacing: -_effectiveFontSize * 0.03
    readonly property real _gap: _effectiveFontSize * 0.10
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
            id: hourLabel
            anchors.verticalCenter: parent.verticalCenter
            text: root.hourText
            color: root.textColor
            opacity: root.digitOpacity
            font.family: root.fontFamily
            font.pixelSize: root._effectiveFontSize
            font.weight: Font.Medium
            font.letterSpacing: root._letterSpacing
            renderType: Text.NativeRendering
        }

        Item {
            id: dotHolder
            width: root._dotDiameter
            height: hourLabel.height
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
            anchors.verticalCenter: parent.verticalCenter
            text: root.minuteText
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
