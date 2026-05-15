import QtQuick

Item {
    id: marquee

    property string text: ""
    property real fontSize: 14
    property bool bold: false
    property int fontWeight: bold ? Font.DemiBold : Font.Regular
    property color textColor: "#ffffff"
    property string fontFamily: ""
    property real textOpacity: 1.0
    property int scrollSpeed: 45
    property int initialPause: 5000
    property int endPause: 3000
    property int maxLoops: 2

    clip: true

    Text {
        id: label
        text: marquee.text
        textFormat: Text.PlainText
        font.pixelSize: marquee.fontSize
        font.weight: marquee.fontWeight
        font.family: marquee.fontFamily
        color: marquee.textColor
        opacity: marquee.textOpacity
        elide: needsScrolling ? Text.ElideNone : Text.ElideRight
        width: needsScrolling ? implicitWidth : parent.width

        property bool needsScrolling: implicitWidth > marquee.width

        x: 0

        SequentialAnimation on x {
            id: scrollAnim
            running: label.needsScrolling
            loops: marquee.maxLoops

            PauseAnimation { duration: marquee.initialPause }

            NumberAnimation {
                from: 0
                to: -(label.implicitWidth - marquee.width)
                duration: label.needsScrolling
                    ? (label.implicitWidth - marquee.width) * marquee.scrollSpeed
                    : 0
                easing.type: Easing.Linear
            }

            PauseAnimation { duration: marquee.endPause }

            NumberAnimation {
                from: -(label.implicitWidth - marquee.width)
                to: 0
                duration: label.needsScrolling
                    ? (label.implicitWidth - marquee.width) * marquee.scrollSpeed
                    : 0
                easing.type: Easing.Linear
            }

            PauseAnimation { duration: marquee.endPause }
        }

        Connections {
            target: marquee
            function onTextChanged() {
                scrollAnim.stop()
                label.x = 0
                if (label.needsScrolling) scrollAnim.restart()
            }
        }
    }
}
