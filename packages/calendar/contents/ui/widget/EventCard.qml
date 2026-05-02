import QtQuick

Item {
    id: card

    property string title: ""
    property string timeLabel: ""
    property color pillColor: "#FF6B6B"
    property color textColor: "#ffffff"
    property string fontFamily: ""
    property real fontSize: 11
    property bool isGlass: true
    property bool isLight: false

    readonly property real _pad: Math.round(height * 0.22)

    implicitHeight: Math.round(fontSize * 2.8)

    Rectangle {
        anchors.fill: parent
        radius: Math.round(card.height * 0.25)
        color: "#ffffff"
        opacity: card.isGlass
            ? (card.isLight ? 0.18 : 0.10)
            : (card.isLight ? 0.08 : 0.15)
    }

    Rectangle {
        id: pill
        x: card._pad
        y: card._pad
        width: 3
        height: parent.height - 2 * card._pad
        radius: 1.5
        color: card.pillColor
    }

    Text {
        anchors.left: pill.right
        anchors.leftMargin: 6
        anchors.right: timeText.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        text: card.title
        color: card.textColor
        font.family: card.fontFamily
        font.pixelSize: card.fontSize
        elide: Text.ElideRight
    }

    Text {
        id: timeText
        anchors.right: parent.right
        anchors.rightMargin: card._pad
        anchors.verticalCenter: parent.verticalCenter
        text: card.timeLabel
        color: card.textColor
        opacity: 0.6
        font.family: card.fontFamily
        font.pixelSize: Math.round(card.fontSize * 0.85)
    }
}
