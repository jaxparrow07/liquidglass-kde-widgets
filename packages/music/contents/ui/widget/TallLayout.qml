import QtQuick
import QtQuick.Layouts

Item {
    id: layout

    required property QtObject colors
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

    readonly property real _m: Math.round(Math.min(width, height) * 0.05)
    readonly property real _s: Math.min(width, height)

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: layout._m

        AlbumArt {
            id: albumArtItem
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(content.width, content.width * 0.9)
            height: Math.min(width, content.height * 0.60)
            artUrl: layout.albumArt
            radius: Math.round(Math.min(width, height) * 0.06)
            fallbackIconColor: layout.colors.foreground
        }

        Column {
            id: infoCol
            anchors.top: albumArtItem.bottom
            anchors.topMargin: Math.round(layout._s * 0.04)
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 2

            MarqueeText {
                width: parent.width
                height: Math.round(layout._s * 0.07) + 4
                text: layout.track || "Not Playing"
                fontSize: Math.max(10, Math.round(layout._s * 0.06))
                fontWeight: Font.DemiBold
                fontFamily: layout.fontFamily
                textColor: layout.colors.foreground
            }

            MarqueeText {
                width: parent.width
                height: Math.max(10, Math.round(layout._s * 0.045)) + 4
                text: layout.artist || "—"
                fontSize: Math.max(8, Math.round(layout._s * 0.045))
                fontWeight: Font.Medium
                fontFamily: layout.fontFamily
                textColor: layout.colors.musicSecondary
            }
        }

        MusicSlider {
            id: slider
            anchors.top: infoCol.bottom
            anchors.topMargin: Math.round(layout._s * 0.04)
            anchors.left: parent.left
            anchors.right: parent.right
            position: layout.position
            length: layout.length
            fillColor: layout.colors.foreground
            trackColor: layout.colors.foreground
            timeLabelColor: layout.colors.foreground
            fontFamily: layout.fontFamily
            fontSize: Math.max(8, Math.round(layout._s * 0.035))
            formatTime: layout.formatTime
            onSeek: function(pos) { layout.seek(pos) }
        }

        Row {
            id: controls
            anchors.top: slider.bottom
            anchors.topMargin: Math.round(layout._s * 0.02)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(layout._s * 0.10)

            readonly property real _playSize: Math.max(20, Math.round(layout._s * 0.12))
            readonly property real _skipSize: Math.max(16, Math.round(layout._s * 0.08))
            readonly property real _rowH: _playSize * 1.6

            ControlButton {
                iconSource: Qt.resolvedUrl("../icons/previous.svg")
                iconColor: layout.colors.foreground
                iconSize: controls._skipSize
                height: controls._rowH
                opacity: layout.canGoPrevious ? 1.0 : 0.3
                onClicked: layout.previousTrack()
            }

            ControlButton {
                iconSource: layout.isPlaying ? Qt.resolvedUrl("../icons/pause.svg") : Qt.resolvedUrl("../icons/play.svg")
                iconColor: layout.colors.foreground
                iconSize: controls._playSize
                height: controls._rowH
                opacity: (layout.canPlay || layout.canPause) ? 1.0 : 0.3
                onClicked: layout.togglePlaying()
            }

            ControlButton {
                iconSource: Qt.resolvedUrl("../icons/next.svg")
                iconColor: layout.colors.foreground
                iconSize: controls._skipSize
                height: controls._rowH
                opacity: layout.canGoNext ? 1.0 : 0.3
                onClicked: layout.nextTrack()
            }
        }
    }
}
