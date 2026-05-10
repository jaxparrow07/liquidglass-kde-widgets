import QtQuick

Item {
    id: hf

    property var slots: []
    property string iconSet: "default"
    property color textColor: "#ffffff"
    property color secondaryTextColor: "#ffffff"
    property real secondaryOpacity: 0.65
    property string fontFamily: ""
    property real baseFontSize: 12
    property real horizontalPadding: 0

    readonly property real _fontSize: baseFontSize * 0.85
    readonly property real _innerWidth: Math.max(0, hf.width - hf.horizontalPadding * 2)
    readonly property real _slotWidth: hf.slots.length > 0 ? hf._innerWidth / hf.slots.length : hf._innerWidth

    Repeater {
        model: hf.slots.length

        Column {
            readonly property int _count: Math.max(1, hf.slots.length)
            readonly property var slot: index < hf.slots.length ? hf.slots[index] : null

            x: _count === 1
                ? (hf.width - width) / 2
                : (hf.horizontalPadding + hf._slotWidth * (index + 0.5)) - width / 2
            y: (hf.height - height) / 2
            spacing: Math.round(hf.height * 0.04)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: slot ? slot.displayTime : "--"
                color: hf.secondaryTextColor
                opacity: hf.secondaryOpacity
                font.family: hf.fontFamily
                font.pixelSize: hf._fontSize
                font.weight: Font.Regular
            }

            WeatherIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                iconName: slot ? slot.iconName : "sunny"
                iconSet: hf.iconSet
                iconSize: Math.round(hf.height * 0.36)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    if (!slot) return "--"
                    if (slot.isSunEvent) return slot.sunEventType
                    return slot.temp + "°"
                }
                color: hf.textColor
                opacity: slot && slot.isSunEvent ? hf.secondaryOpacity : 1.0
                font.family: hf.fontFamily
                font.pixelSize: hf._fontSize
                font.weight: Font.Regular
            }
        }
    }
}
