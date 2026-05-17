import QtQuick

Item {
    id: lv

    required property QtObject colors
    property var syncedLyrics: []
    property string plainLyrics: ""
    property int lyricsState: 0
    property real currentPositionMs: 0
    property string fontFamily: ""
    property real baseFontSize: 20
    property bool blurEnabled: true
    property real activeOpacity: 1.0
    property real inactiveOpacity: 0.40
    property real activeScale: 1.05

    signal seekTo(real positionUs)

    readonly property int _currentIndex: {
        var adj = currentPositionMs + 200
        var idx = -1
        for (var i = 0; i < syncedLyrics.length; i++) {
            if (syncedLyrics[i].timestamp <= adj) idx = i
            else break
        }
        return idx
    }

    property int _previousIndex: -2
    property bool _hasInitialScrolled: false
    property bool _isUserScrolling: false

    readonly property int _visibleCount: Math.max(3, Math.floor(height / (baseFontSize * 2.5)))

    on_CurrentIndexChanged: {
        if (_currentIndex === _previousIndex) return
        _previousIndex = _currentIndex

        if (_currentIndex < 0) return

        if (_isUserScrolling) {
            _isUserScrolling = false
            _snapBackTimer.stop()
        }

        if (!_hasInitialScrolled) {
            _hasInitialScrolled = true
            lyricsList.positionViewAtIndex(_currentIndex, ListView.Beginning)
            return
        }

        lyricsList.currentIndex = _currentIndex
    }

    onSyncedLyricsChanged: {
        _previousIndex = -2
        _hasInitialScrolled = false
        _isUserScrolling = false
    }

    Timer {
        id: _snapBackTimer
        interval: 2000
        onTriggered: {
            lv._isUserScrolling = false
            if (lv._currentIndex >= 0)
                lyricsList.currentIndex = lv._currentIndex
        }
    }

    // ── Synced lyrics ─────────────────────────────────────────────────────
    ListView {
        id: lyricsList
        anchors.fill: parent
        visible: lv.lyricsState === 2 && lv.syncedLyrics.length > 0
        clip: true
        spacing: Math.round(lv.baseFontSize * 0.15)
        topMargin: Math.round(lv.baseFontSize * 0.3)
        bottomMargin: Math.round(height * 0.7)
        model: lv.syncedLyrics.length
        cacheBuffer: Math.round(lv.baseFontSize * 2.5 * 3)
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 600
        highlightMoveVelocity: -1
        preferredHighlightBegin: 0
        preferredHighlightEnd: 0
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightFollowsCurrentItem: true
        highlight: Item {}

        onMovementStarted: {
            if (!lv._isUserScrolling) {
                lv._isUserScrolling = true
            }
        }
        onMovementEnded: {
            if (lv._isUserScrolling)
                _snapBackTimer.restart()
        }
        onFlickStarted: {
            if (!lv._isUserScrolling)
                lv._isUserScrolling = true
        }

        delegate: Item {
            id: del
            width: lyricsList.width
            height: bg.height

            readonly property bool _isActive: index === lv._currentIndex
            readonly property bool _isInstrumental:
                (lv.syncedLyrics[index] ? lv.syncedLyrics[index].text : "") === ""

            readonly property int _dist: index - lv._currentIndex
            readonly property bool _inRange: Math.abs(_dist) <= lv._visibleCount + 3

            readonly property real _scrollDimOpacity: lv.inactiveOpacity * 0.6

            readonly property real _targetOpacity: {
                if (lv._isUserScrolling)
                    return _isActive ? lv.activeOpacity : _scrollDimOpacity

                if (!_inRange) return _dist < 0 ? 0 : lv.inactiveOpacity * 0.15

                if (_isActive) return lv.activeOpacity
                if (_dist < 0) return lv.inactiveOpacity * 0.25
                var frac = Math.min(1, _dist / lv._visibleCount)
                return lv.inactiveOpacity * (1 - frac * 0.85)
            }

            Rectangle {
                id: bg
                width: parent.width
                height: lineText.implicitHeight + _vPad * 2
                radius: Math.round(height * 0.22)
                color: hoverArea.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                readonly property real _activeScale: del._isActive ? lv.activeScale : 1.0
                readonly property real _pressScale: hoverArea.pressed ? 0.97 : 1.0
                scale: _activeScale * _pressScale
                transformOrigin: Item.Left
                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                layer.enabled: _activeScale > 1.01
                layer.smooth: true
                layer.textureSize: Qt.size(width * 2, height * 2)

                readonly property real _vPad: Math.round(lv.baseFontSize * 0.45)
                readonly property real _hPad: Math.round(lv.baseFontSize * 0.6)

                Text {
                    id: lineText
                    x: bg._hPad
                    y: bg._vPad
                    width: bg.width - bg._hPad * 2
                    text: del._isInstrumental ? "♪  ♪  ♪" : lv.syncedLyrics[index].text
                    color: "#ffffff"
                    font.pixelSize: lv.baseFontSize
                    font.weight: Font.Bold
                    font.family: lv.fontFamily
                    font.italic: del._isInstrumental
                    wrapMode: Text.WordWrap
                }
            }

            opacity: _targetOpacity
            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var ts = lv.syncedLyrics[index] ? lv.syncedLyrics[index].timestamp : 0
                    lv.seekTo(ts * 1000)
                }
            }
        }
    }

    // ── Plain lyrics fallback ─────────────────────────────────────────────
    Flickable {
        anchors.fill: parent
        visible: lv.lyricsState === 2 && lv.syncedLyrics.length === 0 && lv.plainLyrics !== ""
        clip: true
        contentHeight: plainText.implicitHeight + 32
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds

        Text {
            id: plainText
            x: 16; y: 16
            width: parent.width - 32
            text: lv.plainLyrics
            color: "#ffffff"
            opacity: 0.85
            font.pixelSize: Math.round(lv.baseFontSize * 0.75)
            font.family: lv.lyricsFontFamily !== "" ? lv.lyricsFontFamily : lv.fontFamily
            wrapMode: Text.WordWrap
            lineHeight: 1.6
        }
    }

    // ── Loading ───────────────────────────────────────────────────────────
    Text {
        anchors.centerIn: parent
        visible: lv.lyricsState === 1
        text: "Loading lyrics…"
        color: "#ffffff"
        font.pixelSize: Math.max(12, Math.round(lv.baseFontSize * 0.8))
        font.weight: Font.Medium
        font.family: lv.fontFamily

        SequentialAnimation on opacity {
            running: lv.lyricsState === 1
            loops: Animation.Infinite
            NumberAnimation { from: 0.45; to: 0.15; duration: 800; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 0.15; to: 0.45; duration: 800; easing.type: Easing.InOutQuad }
        }
    }

    // ── Not found / error ─────────────────────────────────────────────────
    Text {
        anchors.centerIn: parent
        visible: lv.lyricsState >= 3 || (lv.lyricsState === 2 && lv.syncedLyrics.length === 0 && lv.plainLyrics === "")
        text: "No lyrics available"
        color: "#ffffff"
        opacity: 0.45
        font.pixelSize: Math.max(12, Math.round(lv.baseFontSize * 0.8))
        font.weight: Font.Medium
        font.family: lv.fontFamily
    }
}
