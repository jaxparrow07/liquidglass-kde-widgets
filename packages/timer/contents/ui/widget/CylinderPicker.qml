import QtQuick

// The label ("min"/"sec") is rendered outside this Item's bounds.
// Parent must not clip, or must size to include the label area.
Item {
    id: root

    property int count: 60
    property int currentIndex: 0
    property string label: ""
    property string fontFamily: ""
    property color textColor: "#ffffff"
    property color separatorColor: "#ffffff"
    property string labelFontFamily: ""

    readonly property real _itemHeight: height / 5
    readonly property real _visibleRadius: height / 2
    readonly property real _maxAngle: Math.PI / 2.2

    property real _scrollY: currentIndex * _itemHeight
    property bool _externalSet: false

    implicitWidth: 80
    implicitHeight: 180

    onCurrentIndexChanged: {
        if (_externalSet) return
        var target = currentIndex * _itemHeight
        if (Math.abs(_scrollY - target) > 0.5) {
            snapAnim.stop()
            momentumAnim.stop()
            _scrollY = target
        }
    }

    function _snapToNearest() {
        var target = Math.round(_scrollY / _itemHeight) * _itemHeight
        target = Math.max(0, Math.min(target, (count - 1) * _itemHeight))
        snapAnim.to = target
        snapAnim.restart()
    }

    NumberAnimation {
        id: snapAnim
        target: root
        property: "_scrollY"
        duration: 220
        easing.type: Easing.OutCubic
        onFinished: {
            root._externalSet = true
            root.currentIndex = Math.round(root._scrollY / root._itemHeight)
            root._externalSet = false
        }
    }

    NumberAnimation {
        id: momentumAnim
        target: root
        property: "_scrollY"
        duration: 320
        easing.type: Easing.OutCubic
        onFinished: root._snapToNearest()
    }

    // Drum area — clipped so items don't bleed outside
    Item {
        id: drumArea
        anchors.fill: parent
        clip: true

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
                var delta = -event.angleDelta.y / 120.0
                snapAnim.stop()
                momentumAnim.stop()
                var newY = root._scrollY + delta * root._itemHeight * 0.8
                newY = Math.max(0, Math.min(newY, (root.count - 1) * root._itemHeight))
                root._scrollY = newY
                snapTimer.restart()
            }
        }

        Timer {
            id: snapTimer
            interval: 120
            repeat: false
            onTriggered: root._snapToNearest()
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            property real _lastY: 0
            property real _velocity: 0
            property real _prevY: 0

            onPressed: function(mouse) {
                snapAnim.stop()
                momentumAnim.stop()
                snapTimer.stop()
                _lastY = mouse.y
                _prevY = mouse.y
                _velocity = 0
            }

            onPositionChanged: function(mouse) {
                var dy = _lastY - mouse.y
                _velocity = _prevY - mouse.y
                _prevY = _lastY
                _lastY = mouse.y
                var newY = root._scrollY + dy
                newY = Math.max(0, Math.min(newY, (root.count - 1) * root._itemHeight))
                root._scrollY = newY
            }

            onReleased: {
                var momentum = _velocity * 5
                var dest = root._scrollY + momentum
                dest = Math.max(0, Math.min(dest, (root.count - 1) * root._itemHeight))
                if (Math.abs(momentum) > root._itemHeight * 0.3) {
                    momentumAnim.from = root._scrollY
                    momentumAnim.to = dest
                    momentumAnim.restart()
                } else {
                    root._snapToNearest()
                }
            }
        }

        Repeater {
            model: root.count
            delegate: Item {
                id: delegateItem
                required property int index

                readonly property real _rawOffset: (index * root._itemHeight) - root._scrollY
                readonly property real _angle: (_rawOffset / root._visibleRadius) * root._maxAngle
                readonly property real _cosA: Math.cos(_angle)
                // Power of 2.5 makes off-center items fade quickly, emphasizing selection
                readonly property real _itemScale: Math.pow(Math.max(0, _cosA), 0.6)
                readonly property real _itemY: root.height / 2 + Math.sin(_angle) * root._visibleRadius - height / 2

                visible: Math.abs(_angle) < Math.PI / 2
                width: root.width
                height: root._itemHeight
                x: 0
                y: _itemY
                opacity: Math.max(0, Math.pow(_cosA, 2.5))

                transform: Scale {
                    origin.x: delegateItem.width / 2
                    origin.y: delegateItem.height / 2
                    xScale: delegateItem._itemScale
                    yScale: delegateItem._itemScale
                }

                Text {
                    anchors.centerIn: parent
                    text: index < 10 ? "0" + index : String(index)
                    color: root.textColor
                    font.family: root.fontFamily
                    font.pixelSize: root._itemHeight * 0.72
                    font.weight: Font.Thin
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    renderType: Text.NativeRendering
                }
            }
        }

        // Selection indicator lines
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height / 2 - root._itemHeight / 2 - 1
            width: parent.width * 0.85
            height: 1
            color: root.separatorColor
            opacity: 0.20
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height / 2 + root._itemHeight / 2
            width: parent.width * 0.85
            height: 1
            color: root.separatorColor
            opacity: 0.20
        }
    }

    // Label outside the clipped drum area so it's always visible
    Text {
        id: labelText
        anchors {
            left: drumArea.right
            leftMargin: 6
            verticalCenter: drumArea.verticalCenter
        }
        text: root.label
        color: root.textColor
        opacity: 0.45
        font.family: root.labelFontFamily !== "" ? root.labelFontFamily : root.fontFamily
        font.pixelSize: root._itemHeight * 0.52
        font.weight: Font.Regular
        renderType: Text.NativeRendering
    }
}
