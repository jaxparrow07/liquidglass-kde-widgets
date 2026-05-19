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
    property color accentColor: "#ffffff"
    property color lyricsAccentColor: Qt.rgba(1, 1, 1, 0.35)
    property bool lyricsActive: false
    property int flipDirection: 1
    property var formatTime: function(us) { return "" }
    property var syncedLyrics: []
    property string plainLyrics: ""
    property int lyricsState: 0
    property real lyricsPositionMs: 0
    property bool lyricsBlur: true
    property real lyricsActiveOpacity: 1.0
    property real lyricsInactiveOpacity: 0.40
    property real lyricsFontSizeFactor: 0.055

    signal togglePlaying()
    signal nextTrack()
    signal previousTrack()
    signal seek(real positionUs)
    signal toggleLyrics()
    signal retryLyrics()

    readonly property real _m: Math.round(width * 0.08)
    readonly property real _s: width
    readonly property real _btnH: Math.round(_s * 0.075)

    property bool _lyricsAnimating: false
    onLyricsActiveChanged: {
        _lyricsAnimating = true
        _lyricsAnimResetTimer.restart()
    }
    Timer {
        id: _lyricsAnimResetTimer
        interval: 250
        onTriggered: layout._lyricsAnimating = false
    }

    // ── Main content area with margins ─────────────────────────────────────
    Item {
        id: rootContent
        anchors.fill: parent
        anchors.margins: layout._m

        // ── Normal content: album art + info text ─────────────────────────
        Item {
            id: normalContent
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            opacity: layout.lyricsActive ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: layout.lyricsActive ? 250 : 450; easing.type: Easing.OutQuart } }

            FlipAlbumArt {
                id: albumArtItem
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: width
                artUrl: layout.albumArt
                radius: Math.round(width * 0.08)
                fallbackIconColor: layout.colors.foreground
                direction: layout.flipDirection
            }

            Column {
                id: infoCol
                anchors.top: albumArtItem.bottom
                anchors.topMargin: Math.round(layout._s * 0.03)
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 2

                MarqueeText {
                    width: parent.width
                    height: Math.round(layout._s * 0.08) + 4
                    text: layout.track || "Not Playing"
                    fontSize: Math.max(11, Math.round(layout._s * 0.065))
                    fontWeight: Font.DemiBold
                    fontFamily: layout.fontFamily
                    textColor: layout.colors.foreground
                }

                MarqueeText {
                    width: parent.width
                    height: Math.max(10, Math.round(layout._s * 0.055)) + 4
                    text: layout.artist || "—"
                    fontSize: Math.max(9, Math.round(layout._s * 0.05))
                    fontWeight: Font.Medium
                    fontFamily: layout.fontFamily
                    textColor: layout.colors.foreground
                    textOpacity: 0.55
                }
            }

            // ── Slider ────────────────────────────────────────────────────
            MusicSlider {
                id: slider
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                position: layout.position
                length: layout.length
                fillColor: layout.accentColor
                trackColor: layout.colors.foreground
                timeLabelColor: layout.colors.foreground
                fontFamily: layout.fontFamily
                fontSize: Math.max(8, Math.round(layout._s * 0.038))
                formatTime: layout.formatTime
                onSeek: function(pos) { layout.seek(pos) }
            }

}

        // ── Lyrics placeholder (fades in) ─────────────────────────────────
        Item {
            id: lyricsContent
            anchors.top: parent.top
            anchors.topMargin: layout._m
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: lyricsBtn.top
            anchors.bottomMargin: Math.round(layout._s * 0.04)

            opacity: layout.lyricsActive ? 1 : 0
            scale: layout.lyricsActive ? 1 : 0.96
            visible: opacity > 0
            transformOrigin: Item.Center
            Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutQuart } }
            Behavior on scale   { NumberAnimation { duration: 280; easing.type: Easing.OutQuart } }

            SyncedLyricsView {
                anchors.fill: parent
                colors: layout.colors
                syncedLyrics: layout.syncedLyrics
                plainLyrics: layout.plainLyrics
                lyricsState: layout.lyricsState
                currentPositionMs: layout.lyricsPositionMs
                fontFamily: layout.fontFamily
                baseFontSize: Math.max(10, Math.round(layout._s * layout.lyricsFontSizeFactor))
                blurEnabled: layout.lyricsBlur
                activeOpacity: layout.lyricsActiveOpacity
                inactiveOpacity: layout.lyricsInactiveOpacity
                onSeekTo: function(posUs) { layout.seek(posUs) }
                onRetryLyrics: layout.retryLyrics()
            }
        }

        // ── Lyrics button (floating, slides between below-artist and top) ─
        Rectangle {
            id: lyricsBtn
            anchors.right: parent.right
            y: layout.lyricsActive
                ? (layout.height - layout._m - lyricsControls.height - Math.round(layout._s * 0.04) - layout._btnH - layout._m)
                : _btnNormalY
            Behavior on y { enabled: layout._lyricsAnimating; NumberAnimation { duration: 180; easing.type: Easing.InOutQuart } }

            readonly property real _btnNormalY: albumArtItem.height
                + Math.round(layout._s * 0.03)
                + (Math.round(layout._s * 0.08) + 4) + 2
                + (Math.max(10, Math.round(layout._s * 0.055)) + 4) + 2
                + 4

            width: lyricsBtnRow.width + Math.round(layout._s * 0.08)
            height: layout._btnH
            radius: height / 2
            color: layout.lyricsActive ? layout.lyricsAccentColor : Qt.rgba(1, 1, 1, 0.30)
            Behavior on color { ColorAnimation { duration: 280 } }

            Row {
                id: lyricsBtnRow
                anchors.centerIn: parent
                spacing: Math.round(layout._s * 0.02)

                Image {
                    source: Qt.resolvedUrl("../icons/mic.png")
                    width: Math.round(layout._s * 0.04)
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    smooth: true
                    mipmap: true
                }

                Text {
                    text: "Lyrics"
                    color: "#ffffff"
                    font.pixelSize: Math.max(7, Math.round(layout._s * 0.038))
                    font.weight: Font.Medium
                    font.family: layout.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: layout.toggleLyrics()
            }
        }
    }

    Row {
        id: lyricsControls
        anchors.horizontalCenter: parent.horizontalCenter

        readonly property real _normalY: layout.height - layout._m
            - slider.implicitHeight - Math.round(layout._s * 0.03)
            - lyricsControls.height
        y: layout.lyricsActive
            ? (layout.height - layout._m - lyricsControls.height)
            : _normalY
        Behavior on y { enabled: layout._lyricsAnimating; NumberAnimation { duration: 180; easing.type: Easing.InOutQuart } }


        spacing: Math.round(layout._s * 0.08)

        readonly property real _iconSize: Math.max(18, Math.round(layout._s * 0.12))
        readonly property real _rowH: _iconSize * 1.6

        ControlButton {
            iconSource: Qt.resolvedUrl("../icons/previous.svg")
            iconColor: layout.colors.foreground
            iconSize: lyricsControls._iconSize
            height: lyricsControls._rowH
            opacity: layout.canGoPrevious ? 1.0 : 0.3
            onClicked: layout.previousTrack()
        }

        ControlButton {
            iconSource: layout.isPlaying ? Qt.resolvedUrl("../icons/pause.svg") : Qt.resolvedUrl("../icons/play.svg")
            iconColor: layout.colors.foreground
            iconSize: lyricsControls._iconSize
            height: lyricsControls._rowH
            opacity: (layout.canPlay || layout.canPause) ? 1.0 : 0.3
            onClicked: layout.togglePlaying()
        }

        ControlButton {
            iconSource: Qt.resolvedUrl("../icons/next.svg")
            iconColor: layout.colors.foreground
            iconSize: lyricsControls._iconSize
            height: lyricsControls._rowH
            opacity: layout.canGoNext ? 1.0 : 0.3
            onClicked: layout.nextTrack()
        }
    }
}
