import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: layout

    required property QtObject colors
    property real cornerRadius: 24
    property real roundness: 7.5
    property string fontFamily: ""
    property string fontFamilyThin: ""
    property string track: ""
    property string artist: ""
    property string albumArt: ""
    property bool isPlaying: false
    property bool canGoPrevious: false
    property bool canGoNext: false
    property bool canPlay: false
    property bool canPause: false
    property real position: 0
    property real length: 0
    property var formatTime: function(us) { return "" }

    signal togglePlaying()
    signal nextTrack()
    signal previousTrack()
    signal seek(real positionUs)

    readonly property real _m: Math.round(Math.min(width, height) * 0.08)
    readonly property real _s: Math.min(width, height)
    readonly property real _bgArtRadius: Math.min(layout.cornerRadius, Math.min(width, height) * 0.22)

    clip: true

    onCornerRadiusChanged: squircleMask.requestPaint()
    onRoundnessChanged: squircleMask.requestPaint()
    onWidthChanged: squircleMask.requestPaint()
    onHeightChanged: squircleMask.requestPaint()

    // Album art as full background with gradient fade-out toward bottom
    Item {
        id: bgArtContainer
        anchors.fill: parent
        visible: layout.albumArt !== ""

        Item {
            id: bgArtSource
            anchors.fill: parent
            visible: false
            layer.enabled: true

            Image {
                anchors.fill: parent
                source: layout.albumArt
                fillMode: Image.PreserveAspectCrop
                smooth: true
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0;  color: Qt.rgba(0, 0, 0, 0.35) }
                    GradientStop { position: 0.35; color: Qt.rgba(0, 0, 0, 0.45) }
                    GradientStop { position: 0.85; color: Qt.rgba(0, 0, 0, 0.90) }
                    GradientStop { position: 1.0;  color: Qt.rgba(0, 0, 0, 0.97) }
                }
            }
        }

        Item {
            id: bgArtMask
            anchors.fill: parent
            visible: false
            layer.enabled: true

            Canvas {
                id: squircleMask
                anchors.fill: parent

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()

                    var w = width, h = height
                    var r = Math.min(layout.cornerRadius, w / 2, h / 2)
                    var n = Math.max(layout.roundness, 2.0)
                    var steps = 32

                    // Trace the superellipse corner arc matching the shader's SDF:
                    //   q = abs(p) - b + r; corner boundary: (qx^n + qy^n)^(1/n) = r
                    // Parametrically: qx = r*cos(t)^(2/n), qy = r*sin(t)^(2/n)
                    function cornerX(t) { return r * Math.pow(Math.abs(Math.cos(t)), 2.0 / n) }
                    function cornerY(t) { return r * Math.pow(Math.abs(Math.sin(t)), 2.0 / n) }

                    ctx.beginPath()

                    // Start at top-left corner, top tangent point
                    ctx.moveTo(r, 0)

                    // Top edge
                    ctx.lineTo(w - r, 0)

                    // Top-right corner: from (w-r, 0) to (w, r)
                    for (var i = 1; i <= steps; i++) {
                        var t = (1 - i / steps) * Math.PI / 2
                        ctx.lineTo(w - r + cornerX(t), r - cornerY(t))
                    }

                    // Right edge
                    ctx.lineTo(w, h - r)

                    // Bottom-right corner: from (w, h-r) to (w-r, h)
                    for (var i = 1; i <= steps; i++) {
                        var t = (1 - i / steps) * Math.PI / 2
                        ctx.lineTo(w - r + cornerY(t), h - r + cornerX(t))
                    }

                    // Bottom edge
                    ctx.lineTo(r, h)

                    // Bottom-left corner: from (r, h) to (0, h-r)
                    for (var i = 1; i <= steps; i++) {
                        var t = (1 - i / steps) * Math.PI / 2
                        ctx.lineTo(r - cornerX(t), h - r + cornerY(t))
                    }

                    // Left edge
                    ctx.lineTo(0, r)

                    // Top-left corner: from (0, r) to (r, 0)
                    for (var i = 1; i <= steps; i++) {
                        var t = (1 - i / steps) * Math.PI / 2
                        ctx.lineTo(r - cornerY(t), r - cornerX(t))
                    }

                    ctx.closePath()
                    ctx.fillStyle = "white"
                    ctx.fill()
                }
            }
        }

        MultiEffect {
            anchors.fill: parent
            source: bgArtSource
            maskEnabled: true
            maskSource: bgArtMask
            visible: layout.albumArt !== ""
        }
    }

    // Fallback icon when no album art
    Item {
        anchors.fill: parent
        visible: layout.albumArt === ""

        Rectangle {
            anchors.centerIn: parent
            width: layout._s * 0.3
            height: width
            radius: width * 0.15
            color: layout.colors.foreground
            opacity: 0.08
        }
    }

    // Content overlay
    Item {
        id: content
        anchors.fill: parent
        anchors.margins: layout._m

        Column {
            id: infoCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: controls.top
            anchors.bottomMargin: Math.round(layout._s * 0.04)
            spacing: 2

            MarqueeText {
                width: parent.width
                height: Math.round(layout._s * 0.07) + 4
                text: layout.track || "Not Playing"
                fontSize: Math.max(12, Math.round(layout._s * 0.065))
                fontWeight: Font.DemiBold
                fontFamily: layout.fontFamily
                textColor: layout.colors.foreground
            }

            MarqueeText {
                width: parent.width
                height: Math.max(12, Math.round(layout._s * 0.048)) + 4
                text: layout.artist || "—"
                fontSize: Math.max(9, Math.round(layout._s * 0.047))
                fontWeight: Font.Medium
                fontFamily: layout.fontFamily
                textColor: layout.colors.foreground
                textOpacity: 0.55
            }
        }

        Row {
            id: controls
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(layout._s * 0.08)

            readonly property real _iconSize: Math.max(20, Math.round(layout._s * 0.11))
            readonly property real _rowH: _iconSize * 1.6

            ControlButton {
                iconSource: Qt.resolvedUrl("../icons/previous.svg")
                iconColor: layout.colors.foreground
                iconSize: controls._iconSize
                height: controls._rowH
                opacity: layout.canGoPrevious ? 1.0 : 0.3
                onClicked: layout.previousTrack()
            }

            ControlButton {
                iconSource: layout.isPlaying ? Qt.resolvedUrl("../icons/pause.svg") : Qt.resolvedUrl("../icons/play.svg")
                iconColor: layout.colors.foreground
                iconSize: controls._iconSize
                height: controls._rowH
                opacity: (layout.canPlay || layout.canPause) ? 1.0 : 0.3
                onClicked: layout.togglePlaying()
            }

            ControlButton {
                iconSource: Qt.resolvedUrl("../icons/next.svg")
                iconColor: layout.colors.foreground
                iconSize: controls._iconSize
                height: controls._rowH
                opacity: layout.canGoNext ? 1.0 : 0.3
                onClicked: layout.nextTrack()
            }
        }
    }
}
