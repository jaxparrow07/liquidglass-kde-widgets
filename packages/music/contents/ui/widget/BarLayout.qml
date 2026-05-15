import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

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
    property var cavaBarValues: []
    property bool cavaAvailable: false
    property real playerVolume: -1
    property bool isMuted: false
    property var formatTime: function(us) { return "" }

    signal togglePlaying()
    signal nextTrack()
    signal previousTrack()
    signal seek(real positionUs)
    signal toggleMute()

    readonly property real _h: height
    readonly property real _pad: Math.round(_h * 0.12)
    readonly property real _contentH: _h - progressLine.height

    // Thin bottom progress line
    Rectangle {
        id: progressLine
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 2
        color: "transparent"

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: layout.length > 0
                ? parent.width * Math.min(1, layout.position / layout.length)
                : 0
            color: layout.colors.foreground
            opacity: 0.6

            Behavior on width {
                NumberAnimation { duration: 200 }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: layout.colors.foreground
            opacity: 0.15
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: layout._contentH
        anchors.leftMargin: layout._pad
        anchors.rightMargin: layout._pad
        spacing: 0

        // Left group: art + info
        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: Math.round(layout._h * 0.10)

            AlbumArt {
                id: artItem
                width: layout._contentH - layout._pad
                height: width
                anchors.verticalCenter: parent.verticalCenter
                artUrl: layout.albumArt
                radius: Math.round(width * 0.12)
                fallbackIconColor: layout.colors.foreground
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(60, layout.width * 0.18)
                spacing: 1

                MarqueeText {
                    width: parent.width
                    height: Math.round(layout._h * 0.30) + 2
                    text: layout.track || "Not Playing"
                    fontSize: Math.max(9, Math.round(layout._h * 0.24))
                    fontWeight: Font.DemiBold
                    fontFamily: layout.fontFamily
                    textColor: layout.colors.foreground
                }

                MarqueeText {
                    width: parent.width
                    height: Math.max(9, Math.round(layout._h * 0.18)) + 2
                    text: layout.artist || "—"
                    fontSize: Math.max(7, Math.round(layout._h * 0.18))
                    fontWeight: Font.Medium
                    fontFamily: layout.fontFamily
                    textColor: layout.colors.musicSecondary
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Center: controls
        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: Math.round(layout._h * 0.12)

            readonly property real _playSize: Math.max(16, Math.round(layout._h * 0.30))
            readonly property real _skipSize: Math.max(12, Math.round(layout._h * 0.22))
            readonly property real _rowH: _playSize * 1.6

            ControlButton {
                iconSource: Qt.resolvedUrl("../icons/previous.svg")
                iconColor: layout.colors.foreground
                iconSize: parent._skipSize
                height: parent._rowH
                opacity: layout.canGoPrevious ? 1.0 : 0.3
                onClicked: layout.previousTrack()
            }

            ControlButton {
                iconSource: layout.isPlaying ? Qt.resolvedUrl("../icons/pause.svg") : Qt.resolvedUrl("../icons/play.svg")
                iconColor: layout.colors.foreground
                iconSize: parent._playSize
                height: parent._rowH
                opacity: (layout.canPlay || layout.canPause) ? 1.0 : 0.3
                onClicked: layout.togglePlaying()
            }

            ControlButton {
                iconSource: Qt.resolvedUrl("../icons/next.svg")
                iconColor: layout.colors.foreground
                iconSize: parent._skipSize
                height: parent._rowH
                opacity: layout.canGoNext ? 1.0 : 0.3
                onClicked: layout.nextTrack()
            }
        }

        Item { Layout.fillWidth: true }

        // Right: spectrum + mute
        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: Math.round(layout._h * 0.10)

            AudioSpectrum {
                width: Math.max(60, layout.width * 0.15)
                height: layout._contentH * 0.6
                anchors.verticalCenter: parent.verticalCenter
                barValues: layout.cavaBarValues
                cavaAvailable: layout.cavaAvailable
                isPlaying: layout.isPlaying
                barColor: layout.colors.foreground
            }

            Item {
                width: Math.round(layout._h * 0.45)
                height: width
                anchors.verticalCenter: parent.verticalCenter
                visible: layout.playerVolume >= 0

                Kirigami.Icon {
                    id: muteIcon
                    anchors.centerIn: parent
                    width: Math.max(14, Math.round(layout._h * 0.28))
                    height: width
                    source: layout.isMuted ? "audio-volume-muted" : "audio-volume-high"
                    color: layout.colors.foreground
                    opacity: 0.7

                    scale: 1.0
                    SequentialAnimation {
                        id: muteBounce
                        NumberAnimation {
                            target: muteIcon; property: "scale"
                            to: 0.75; duration: 80
                            easing.type: Easing.InQuad
                        }
                        NumberAnimation {
                            target: muteIcon; property: "scale"
                            to: 1.0; duration: 250
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.0
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        muteBounce.restart()
                        layout.toggleMute()
                    }
                }
            }
        }
    }
}
