import QtQuick
import QtQuick.Effects

Item {
    id: root

    property string value: "0"
    property color textColor: "#ffffff"
    property string fontFamily: ""
    property real fontPixelSize: 96
    property real digitOpacity: 0.7
    property real maxBlur: 1.0
    property int duration: 400

    readonly property real _glyphHeight: fm.ascent + fm.descent
    readonly property real _p: clamp(_progress, 0, 1)
    readonly property real _speed: Math.sin(Math.PI * _p)
    readonly property real _springOffset: Math.sin(Math.PI * _springT) * _glyphHeight * 0.05
    property string _restValue: value
    property string _fromValue: value
    property string _toValue: value
    property bool _transitioning: false
    property real _progress: 1
    property real _springT: 0
    property real _incomingScale: 1
    property real _outgoingScale: 1

    FontMetrics {
        id: fm
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: Font.Thin
    }

    implicitWidth: fontPixelSize * 0.72
    implicitHeight: fontPixelSize * 1.7

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v))
    }

    function startTransition(nextValue) {
        if (nextValue === _restValue && !_transitioning) {
            return
        }

        _fromValue = _transitioning ? _toValue : _restValue
        _toValue = nextValue
        _progress = 0
        _springT = 0
        _transitioning = true
        rollAnimation.restart()
    }

    onValueChanged: startTransition(value)

    Text {
        id: restDigit
        anchors.centerIn: parent
        visible: !root._transitioning
        text: root._restValue
        color: root.textColor
        opacity: root.digitOpacity
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: Font.Thin
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.NativeRendering
    }

    Text {
        id: outgoingDigit
        width: root.width
        height: root._glyphHeight
        x: 0
        y: (root.height - height) / 2 + root._springOffset
        visible: root._transitioning
        text: root._fromValue
        color: root.textColor
        opacity: root.digitOpacity * (1 - root.clamp((root._p - 0.55) / 0.40, 0, 1))
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: Font.Thin
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.QtRendering
        transform: Scale {
            origin.x: outgoingDigit.width / 2
            origin.y: outgoingDigit.height
            xScale: root._outgoingScale
            yScale: root._outgoingScale
        }
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 96
            blur: root.maxBlur * root.clamp(Math.pow(root._p, 0.45) * 0.52 + root._speed * 0.30, 0, 1)
        }
    }

    Text {
        id: incomingDigit
        width: root.width
        height: root._glyphHeight
        x: 0
        y: (root.height - height) / 2 + root._springOffset
        visible: root._transitioning
        text: root._toValue
        color: root.textColor
        opacity: root.digitOpacity * root.clamp(root._p / 0.30, 0, 1)
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: Font.Thin
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.QtRendering
        transform: Scale {
            origin.x: incomingDigit.width / 2
            origin.y: 0
            xScale: root._incomingScale
            yScale: root._incomingScale
        }
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 96
            blur: root.maxBlur * root.clamp(Math.pow(1 - root._p, 0.45) * 0.64 + root._speed * 0.26, 0, 1)
        }
    }

    SequentialAnimation {
        id: rollAnimation
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "_progress"
                from: 0
                to: 1
                duration: root.duration
                easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: Math.round(root.duration * 0.22)
                }
                NumberAnimation {
                    target: root
                    property: "_springT"
                    from: 0
                    to: 1
                    duration: Math.round(root.duration * 0.78)
                    easing.type: Easing.InOutCubic
                }
            }
            NumberAnimation {
                target: root
                property: "_incomingScale"
                from: 0.0
                to: 1.0
                duration: root.duration
                easing.type: Easing.OutQuint
            }
            NumberAnimation {
                target: root
                property: "_outgoingScale"
                from: 1.0
                to: 0.0
                duration: root.duration
                easing.type: Easing.OutQuint
            }
        }
        onFinished: {
            root._restValue = root._toValue
            root._progress = 1
            root._springT = 0
            root._incomingScale = 1
            root._outgoingScale = 1
            root._transitioning = false
        }
    }
}
