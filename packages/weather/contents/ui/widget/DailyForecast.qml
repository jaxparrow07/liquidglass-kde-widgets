import QtQuick

Item {
    id: df

    property var days: []
    property real overallLow: 0
    property real overallHigh: 100
    property string iconSet: "default"
    property color textColor: "#ffffff"
    property color secondaryColor: "#ffffff"
    property real secondaryOpacity: 0.65
    property color rangeBarBg: Qt.rgba(1, 1, 1, 0.12)
    property color rangeBarFill: Qt.rgba(1, 1, 1, 0.50)
    property string fontFamily: ""
    property real fontSize: 12
    property real rowSpacing: Math.round(df.height * 0.02)
    property bool centerContentVertically: false
    property var iconNameForCode

    readonly property real _rowHeight: Math.max(fontSize * 1.7, 24)
    readonly property real contentHeight: {
        const count = Math.max(1, df.days.length)
        return count * df._rowHeight + (count - 1) * df.rowSpacing
    }

    Column {
        id: contentColumn

        anchors.fill: parent
        anchors.top: df.centerContentVertically ? undefined : parent.top
        anchors.bottom: df.centerContentVertically ? undefined : parent.bottom
        anchors.verticalCenter: df.centerContentVertically ? parent.verticalCenter : undefined
        height: df.centerContentVertically ? Math.min(df.height, df.contentHeight) : df.height
        spacing: df.rowSpacing

        Repeater {
            model: df.days.length

            Item {
                width: df.width
                height: (contentColumn.height - (df.days.length - 1) * contentColumn.spacing) / Math.max(1, df.days.length)

                readonly property var entry: index < df.days.length ? df.days[index] : null
                readonly property real range: df.overallHigh - df.overallLow

                Text {
                    id: dayLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.13
                    text: entry ? entry.day : "--"
                    color: df.textColor
                    font.family: df.fontFamily
                    font.pixelSize: df.fontSize
                    font.weight: Font.Medium
                }

                WeatherIcon {
                    id: dayIcon
                    anchors.left: dayLabel.right
                    anchors.leftMargin: parent.width * 0.02
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: entry && df.iconNameForCode ? df.iconNameForCode(entry.weatherCode, false) : "sunny"
                    iconSet: df.iconSet
                    iconSize: Math.min(parent.height * 0.75, df.fontSize * 1.8)
                }

                Text {
                    id: lowLabel
                    anchors.left: dayIcon.right
                    anchors.leftMargin: parent.width * 0.03
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.08
                    text: entry ? entry.low + "°" : "--"
                    color: df.secondaryColor
                    opacity: df.secondaryOpacity
                    font.family: df.fontFamily
                    font.pixelSize: df.fontSize
                    horizontalAlignment: Text.AlignRight
                }

                Item {
                    id: barContainer
                    anchors.left: lowLabel.right
                    anchors.leftMargin: parent.width * 0.03
                    anchors.right: highLabel.left
                    anchors.rightMargin: parent.width * 0.03
                    anchors.verticalCenter: parent.verticalCenter
                    height: Math.max(4, Math.round(df.fontSize * 0.35))

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: df.rangeBarBg
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        radius: height / 2
                        color: df.rangeBarFill
                        x: {
                            if (!entry || range <= 0) return 0
                            return (parseFloat(entry.low) - df.overallLow) / range * parent.width
                        }
                        width: {
                            if (!entry || range <= 0) return parent.width
                            return Math.max(height, (parseFloat(entry.high) - parseFloat(entry.low)) / range * parent.width)
                        }
                    }
                }

                Text {
                    id: highLabel
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.08
                    text: entry ? entry.high + "°" : "--"
                    color: df.textColor
                    font.family: df.fontFamily
                    font.pixelSize: df.fontSize
                    horizontalAlignment: Text.AlignLeft
                }
            }
        }
    }
}
