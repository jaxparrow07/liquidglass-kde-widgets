import QtQuick
import QtQuick.Effects

Item {
    id: btn

    property string iconSource: ""
    property color iconColor: "#ffffff"
    property real iconSize: 24

    signal clicked()

    implicitWidth: iconSize * 1.6
    implicitHeight: iconSize * 1.6

    Item {
        id: iconItem
        anchors.centerIn: parent
        width: btn.iconSize
        height: btn.iconSize
        scale: 1.0

        layer.enabled: true
        layer.effect: MultiEffect {
            colorization: 1.0
            colorizationColor: btn.iconColor
        }

        Image {
            anchors.fill: parent
            source: btn.iconSource
            sourceSize: Qt.size(btn.iconSize, btn.iconSize)
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        SequentialAnimation {
            id: bounceAnim
            NumberAnimation {
                target: iconItem; property: "scale"
                to: 0.7; duration: 100
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: iconItem; property: "scale"
                to: 1.0; duration: 300
                easing.type: Easing.OutBack
                easing.overshoot: 2.5
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            bounceAnim.restart()
            btn.clicked()
        }
    }
}
