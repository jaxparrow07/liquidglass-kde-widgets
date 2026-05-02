import QtQuick

Item {
    id: card

    property string label: ""
    property color pillColor: "#4ECDC4"
    property color textColor: "#ffffff"
    property string fontFamily: ""
    property real fontSize: 11
    property bool isGlass: true
    property bool isLight: false
    property bool active: true

    signal clicked()

    readonly property real _pad: Math.round(height * 0.22)

    implicitHeight: Math.round(fontSize * 2.8)

    opacity: card.active ? 1.0 : 0.35
    Behavior on opacity { NumberAnimation { duration: 150 } }

    Rectangle {
        id: cardBg
        anchors.fill: parent
        radius: Math.round(card.height * 0.25)
        color: "#ffffff"
        opacity: {
            var base = card.isGlass
                ? (card.isLight ? 0.18 : 0.10)
                : (card.isLight ? 0.08 : 0.15)
            if (mouseArea.pressed) return base * 2.2
            if (mouseArea.containsMouse) return base * 1.7
            return base
        }
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: card._pad + 3 + 6
        anchors.verticalCenter: parent.verticalCenter
        text: card.label
        color: card.textColor
        font.family: card.fontFamily
        font.pixelSize: card.fontSize
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: card.active
        hoverEnabled: true
        onClicked: card.clicked()
    }
}
