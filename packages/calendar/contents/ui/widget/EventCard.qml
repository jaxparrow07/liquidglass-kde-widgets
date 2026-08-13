import QtQuick

Item {
    id: card

    property string title: ""
    property string timeLabel: ""
    property color pillColor: "#FF6B6B"
    property color textColor: "#ffffff"
    property string fontFamily: ""
    property real fontSize: 11
    property color cardBg: "#ffffff"
    property real cardBgOpacity: 0.10
    property bool isCustom: false

    signal deleteRequested()

    readonly property real _pad: Math.round(height * 0.22)

    implicitHeight: Math.round(fontSize * 2.8)

    Rectangle {
        anchors.fill: parent
        radius: Math.round(card.height * 0.25)
        color: card.cardBg
        opacity: card.cardBgOpacity
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
        visible: !deleteBtn.visible
        text: card.timeLabel
        color: card.textColor
        opacity: 0.6
        font.family: card.fontFamily
        font.pixelSize: Math.round(card.fontSize * 0.85)
    }

    MouseArea {
        id: cardHover
        anchors.fill: parent
        hoverEnabled: card.isCustom
        onClicked: (mouse) => {
            if (card.isCustom && deleteBtn.visible) {
                const p = mapToItem(deleteBtn, mouse.x, mouse.y);
                if (p.x >= 0 && p.y >= 0 && p.x <= deleteBtn.width && p.y <= deleteBtn.height)
                    card.deleteRequested();
            }
        }
    }

    Rectangle {
        id: deleteBtn
        anchors.right: parent.right
        anchors.rightMargin: card._pad
        anchors.verticalCenter: parent.verticalCenter
        visible: card.isCustom && cardHover.containsMouse
        width: Math.round(card.height * 0.42)
        height: width
        radius: width / 2
        color: Qt.rgba(1, 1, 1, 0.15)

        Text {
            anchors.centerIn: parent
            text: "\u00D7"
            color: card.textColor
            font.family: card.fontFamily
            font.pixelSize: Math.round(card.fontSize * 0.9)
        }
    }
}
