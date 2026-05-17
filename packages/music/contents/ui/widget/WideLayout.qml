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
    property real lyricsActiveScale: 1.05
    property real lyricsFontSizeFactor: 0.077

    signal togglePlaying()
    signal nextTrack()
    signal previousTrack()
    signal seek(real positionUs)
    signal toggleLyrics()

    readonly property real _m: Math.round(height * 0.08)
    readonly property real _s: height

    // ── Normal content (fades out in lyrics mode) ──────────────────────────
    Item {
        id: normalContent
        anchors.fill: parent

        opacity: layout.lyricsActive ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutQuart } }

        Item {
            id: content
            anchors.fill: parent
            anchors.margins: layout._m

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
                fontSize: Math.max(9, Math.round(layout._s * 0.046))
                formatTime: layout.formatTime
                onSeek: function(pos) { layout.seek(pos) }
            }

            Item {
                id: topRow
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: slider.top
                anchors.bottomMargin: Math.round(layout._s * 0.03)

                FlipAlbumArt {
                    id: albumArtItem
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    width: height
                    artUrl: layout.albumArt
                    radius: Math.round(height * 0.08)
                    fallbackIconColor: layout.colors.foreground
                    direction: layout.flipDirection
                }

                Item {
                    id: rightSection
                    anchors.top: parent.top
                    anchors.left: albumArtItem.right
                    anchors.leftMargin: layout._m
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom

                    Column {
                        id: infoCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: Math.round(layout._s * 0.02)
                        spacing: 2

                        MarqueeText {
                            width: parent.width - lyricsBtn.width - Math.round(layout._s * 0.04)
                            height: Math.round(layout._s * 0.09) + 4
                            text: layout.track || "Not Playing"
                            fontSize: Math.max(11, Math.round(layout._s * 0.081))
                            fontWeight: Font.DemiBold
                            fontFamily: layout.fontFamily
                            textColor: layout.colors.foreground
                        }

                        MarqueeText {
                            width: parent.width
                            height: Math.max(11, Math.round(layout._s * 0.059)) + 4
                            text: layout.artist || "—"
                            fontSize: Math.max(9, Math.round(layout._s * 0.059))
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
                        spacing: Math.round(layout._s * 0.06)

                        readonly property real _iconSize: Math.max(24, Math.round(layout._s * 0.16))
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
        }
    }

    // ── Lyrics view (fades in, covers full widget) ─────────────────────────
    Item {
        id: lyricsView
        anchors.fill: parent

        opacity: layout.lyricsActive ? 1 : 0
        scale: layout.lyricsActive ? 1 : 0.96
        visible: opacity > 0
        transformOrigin: Item.Center
        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutQuart } }
        Behavior on scale   { NumberAnimation { duration: 280; easing.type: Easing.OutQuart } }

        SyncedLyricsView {
            anchors.fill: parent
            anchors.topMargin: lyricsBtn.height + layout._m
            anchors.leftMargin: layout._m
            anchors.rightMargin: layout._m
            anchors.bottomMargin: layout._m
            colors: layout.colors
            syncedLyrics: layout.syncedLyrics
            plainLyrics: layout.plainLyrics
            lyricsState: layout.lyricsState
            currentPositionMs: layout.lyricsPositionMs
            fontFamily: layout.fontFamily
            baseFontSize: Math.max(12, Math.round(layout._s * layout.lyricsFontSizeFactor))
            blurEnabled: layout.lyricsBlur
            activeOpacity: layout.lyricsActiveOpacity
            inactiveOpacity: layout.lyricsInactiveOpacity
            activeScale: layout.lyricsActiveScale
            onSeekTo: function(posUs) { layout.seek(posUs) }
        }
    }

    // ── Single persistent lyrics button (always on top, fixed position) ────
    Rectangle {
        id: lyricsBtn
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: layout._m
        anchors.rightMargin: layout._m
        width: lyricsBtnRow.width + Math.round(layout._s * 0.08)
        height: Math.round(layout._s * 0.09)
        radius: height / 2
        color: layout.lyricsActive ? layout.lyricsAccentColor : Qt.rgba(1, 1, 1, 0.30)
        Behavior on color { ColorAnimation { duration: 280 } }

        Row {
            id: lyricsBtnRow
            anchors.centerIn: parent
            spacing: Math.round(layout._s * 0.025)

            Image {
                source: Qt.resolvedUrl("../icons/mic.png")
                width: Math.round(layout._s * 0.055)
                height: width
                anchors.verticalCenter: parent.verticalCenter
                smooth: true
                mipmap: true
            }

            Text {
                text: "Lyrics"
                color: "#ffffff"
                font.pixelSize: Math.max(8, Math.round(layout._s * 0.05))
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
