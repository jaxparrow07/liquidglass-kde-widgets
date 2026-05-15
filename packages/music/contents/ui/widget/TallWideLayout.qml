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
    property var formatTime: function(us) { return "" }

    signal togglePlaying()
    signal nextTrack()
    signal previousTrack()
    signal seek(real positionUs)

    readonly property real _m: Math.round(width * 0.08)
    readonly property real _s: width

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: layout._m

        AlbumArt {
            id: albumArtItem
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: width
            artUrl: layout.albumArt
            radius: Math.round(width * 0.08)
            fallbackIconColor: layout.colors.foreground
        }

        Item {
            id: bottomSection
            anchors.top: albumArtItem.bottom
            anchors.topMargin: Math.round(layout._s * 0.03)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            Column {
                id: infoCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
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

            Row {
                id: controls
                anchors.top: infoCol.bottom
                anchors.topMargin: Math.round(layout._s * 0.06)
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(layout._s * 0.08)

                readonly property real _iconSize: Math.max(18, Math.round(layout._s * 0.12))
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
