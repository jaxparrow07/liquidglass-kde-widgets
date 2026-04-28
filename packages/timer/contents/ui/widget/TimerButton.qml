import QtQuick
import QtQuick.Effects

Item {
    id: btn

    property real diameter: 64
    property url iconSource: ""
    property color iconColor: "#ffffff"
    property color backgroundColor: Qt.rgba(1, 1, 1, 0.18)

    signal clicked()

    width: diameter
    height: diameter

    Rectangle {
        anchors.fill: parent
        radius: btn.diameter / 2
        color: btn.backgroundColor
        opacity: mouseArea.pressed ? 0.5 : 1.0
        Behavior on opacity { NumberAnimation { duration: 80 } }
    }

    Image {
        id: iconImage
        anchors.centerIn: parent
        width: btn.diameter * 0.42
        height: btn.diameter * 0.42
        source: btn.iconSource
        sourceSize.width: 96
        sourceSize.height: 96
        fillMode: Image.PreserveAspectFit
        smooth: true

        layer.enabled: true
        layer.effect: MultiEffect {
            colorization: 1.0
            colorizationColor: btn.iconColor
            brightness: 1.0
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        onClicked: btn.clicked()
    }
}
