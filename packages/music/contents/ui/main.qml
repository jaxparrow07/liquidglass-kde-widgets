import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.mpris as Mpris
import "components"
import "widget"

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    MacOSColors {
        id: colors
        styleMode: plasmoid.configuration.styleMode
        appearance: plasmoid.configuration.appearance
        foregroundDarkOverride: isSolid && root._hasSampledColor ? root._sampledIsDark : null
    }

    FontLoader { id: sfThin;    source: Qt.resolvedUrl("../fonts/sf_pro_display_thin.otf") }
    FontLoader { id: sfRegular; source: Qt.resolvedUrl("../fonts/sf_pro_display_regular.otf") }

    // ── MPRIS ─────────────────────────────────────────────────────────────

    Mpris.Mpris2Model { id: mpris2Model }

    readonly property string track:   mpris2Model.currentPlayer?.track ?? ""
    readonly property string artist:  mpris2Model.currentPlayer?.artist ?? ""
    readonly property string album:   mpris2Model.currentPlayer?.album ?? ""
    readonly property string albumArt: mpris2Model.currentPlayer?.artUrl ?? ""
    readonly property int playbackStatus: mpris2Model.currentPlayer?.playbackStatus ?? 0
    readonly property bool isPlaying: playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property bool canGoPrevious: mpris2Model.currentPlayer?.canGoPrevious ?? false
    readonly property bool canGoNext:     mpris2Model.currentPlayer?.canGoNext ?? false
    readonly property bool canPlay:  mpris2Model.currentPlayer?.canPlay ?? false
    readonly property bool canPause: mpris2Model.currentPlayer?.canPause ?? false
    readonly property real length: mpris2Model.currentPlayer?.length ?? 0

    property real position: 0

    Connections {
        target: mpris2Model.currentPlayer
        function onPositionChanged() {
            root.position = mpris2Model.currentPlayer?.position ?? 0
        }
    }

    Timer {
        id: positionTimer
        interval: 250
        running: root.isPlaying && root.length > 0
        repeat: true
        onTriggered: {
            if (root.position < root.length)
                root.position += interval * 1000
        }
    }

    onTrackChanged: {
        root.position = mpris2Model.currentPlayer?.position ?? 0
        root._lastSampledUrl = ""
        _scheduleArtRefresh()
    }
    onIsPlayingChanged: root.position = mpris2Model.currentPlayer?.position ?? 0

    Timer {
        id: artRefreshTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (mpris2Model.currentPlayer && root.isPlaying) {
                mpris2Model.currentPlayer.Pause()
                artResumeTimer.start()
            }
        }
    }

    Timer {
        id: artResumeTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (mpris2Model.currentPlayer) mpris2Model.currentPlayer.Play()
        }
    }

    function _scheduleArtRefresh() {
        artRefreshTimer.stop()
        artResumeTimer.stop()
        if (root.isPlaying) artRefreshTimer.start()
    }

    function togglePlaying() {
        if (mpris2Model.currentPlayer) mpris2Model.currentPlayer.PlayPause()
    }
    function next() {
        if (!mpris2Model.currentPlayer) return
        mpris2Model.currentPlayer.Next()
    }
    function previous() {
        if (!mpris2Model.currentPlayer) return
        mpris2Model.currentPlayer.Previous()
    }
    function seek(positionUs) {
        if (mpris2Model.currentPlayer) {
            var current = mpris2Model.currentPlayer.position ?? 0
            var offset = positionUs - current
            mpris2Model.currentPlayer.Seek(offset)
            root.position = positionUs
        }
    }

    function formatTime(us) {
        var totalSec = Math.floor(us / 1000000)
        var h = Math.floor(totalSec / 3600)
        var m = Math.floor((totalSec % 3600) / 60)
        var s = totalSec % 60
        var ss = s < 10 ? "0" + s : "" + s
        if (h > 0) return h + ":" + (m < 10 ? "0" + m : m) + ":" + ss
        return m + ":" + ss
    }

    // ── Album art color sampling ────────────────────────────────────────
    property color _sampledTint: "#000000"
    property color _sampledGradientTop: "#1A1B1E"
    property color _sampledGradientBottom: "#0E0F11"
    property color _sampledPrimaryColor: "#ffffff"
    property bool _hasSampledColor: false
    property bool _sampledIsDark: true

    function _hslToRgb(h, s, l) {
        var c = (1 - Math.abs(2 * l - 1)) * s
        var x = c * (1 - Math.abs((h * 6) % 2 - 1))
        var m = l - c / 2
        var r, g, b
        switch (Math.floor(h * 6) % 6) {
            case 0: r = c; g = x; b = 0; break
            case 1: r = x; g = c; b = 0; break
            case 2: r = 0; g = c; b = x; break
            case 3: r = 0; g = x; b = c; break
            case 4: r = x; g = 0; b = c; break
            case 5: r = c; g = 0; b = x; break
        }
        return Qt.rgba(r + m, g + m, b + m, 1.0)
    }

    function _rgbToHsl(r, g, b) {
        var mx = Math.max(r, g, b), mn = Math.min(r, g, b)
        var l = (mx + mn) / 2, s = 0, h = 0
        if (mx !== mn) {
            var dd = mx - mn
            s = l > 0.5 ? dd / (2 - mx - mn) : dd / (mx + mn)
            if (mx === r)      h = ((g - b) / dd + (g < b ? 6 : 0)) / 6
            else if (mx === g) h = ((b - r) / dd + 2) / 6
            else               h = ((r - g) / dd + 4) / 6
        }
        return { h: h, s: s, l: l }
    }

    property string _lastSampledUrl: ""

    onAlbumArtChanged: {
        if (albumArt !== "") {
            sampleCanvas.loadImage(albumArt)
        } else {
            _hasSampledColor = false
            _sampledTint = "#000000"
            _sampledGradientTop = "#1A1B1E"
            _sampledGradientBottom = "#0E0F11"
            _sampledPrimaryColor = "#ffffff"
            _sampledIsDark = true
            _lastSampledUrl = ""
        }
    }

    Canvas {
        id: sampleCanvas
        width: 64
        height: 64
        visible: true
        opacity: 0

        Component.onCompleted: {
            if (root.albumArt !== "") loadImage(root.albumArt)
        }

        onImageLoaded: {
            if (root.albumArt !== "" && root.albumArt !== root._lastSampledUrl) {
                root._lastSampledUrl = root.albumArt
                requestPaint()
            }
        }

        onPaint: {
            var url = root.albumArt
            if (!url || !isImageLoaded(url)) return

            var ctx = getContext("2d")
            ctx.reset()
            ctx.drawImage(url, 0, 0, 64, 64)

            var imgData = ctx.getImageData(0, 0, 64, 64)
            var d = imgData.data
            var pixels = []
            for (var i = 0; i < d.length; i += 4) {
                if (d[i+3] < 128) continue
                pixels.push([d[i], d[i+1], d[i+2]])
            }
            if (pixels.length === 0) return

            function medianCut(px, depth) {
                if (depth === 0 || px.length === 0) {
                    var rS = 0, gS = 0, bS = 0
                    for (var j = 0; j < px.length; j++) {
                        rS += px[j][0]; gS += px[j][1]; bS += px[j][2]
                    }
                    var n = px.length || 1
                    return [{ r: rS/n/255, g: gS/n/255, b: bS/n/255, count: px.length }]
                }

                var rMin = 255, rMax = 0, gMin = 255, gMax = 0, bMin = 255, bMax = 0
                for (var j = 0; j < px.length; j++) {
                    var p = px[j]
                    if (p[0] < rMin) rMin = p[0]; if (p[0] > rMax) rMax = p[0]
                    if (p[1] < gMin) gMin = p[1]; if (p[1] > gMax) gMax = p[1]
                    if (p[2] < bMin) bMin = p[2]; if (p[2] > bMax) bMax = p[2]
                }
                var rR = rMax - rMin, gR = gMax - gMin, bR = bMax - bMin
                var ch = rR >= gR && rR >= bR ? 0 : (gR >= bR ? 1 : 2)

                px.sort(function(a, b) { return a[ch] - b[ch] })
                var mid = Math.floor(px.length / 2)

                return medianCut(px.slice(0, mid), depth - 1)
                       .concat(medianCut(px.slice(mid), depth - 1))
            }

            var buckets = medianCut(pixels, 3)

            var accentIdx = 0, maxSat = -1
            for (var i = 0; i < buckets.length; i++) {
                var hsl = root._rgbToHsl(buckets[i].r, buckets[i].g, buckets[i].b)
                buckets[i].h = hsl.h; buckets[i].s = hsl.s; buckets[i].l = hsl.l
                buckets[i].lum = 0.299 * buckets[i].r + 0.587 * buckets[i].g + 0.114 * buckets[i].b
                var score = hsl.s * (0.3 + 0.7 * (1 - Math.abs(2 * hsl.l - 1)))
                if (score > maxSat) { maxSat = score; accentIdx = i }
            }

            var sorted = buckets.slice().sort(function(a, b) { return b.count - a.count })
            var dominant = sorted[0]
            var secondary = sorted.length > 1 ? sorted[1] : sorted[0]
            var accent = buckets[accentIdx]

            root._sampledTint = root._hslToRgb(accent.h,
                Math.min(accent.s, 0.5),
                Math.min(accent.l, 0.30))

            root._sampledGradientTop = root._hslToRgb(dominant.h,
                Math.max(dominant.s, 0.30),
                0.15 + dominant.l * 0.35)
            root._sampledGradientBottom = root._hslToRgb(
                secondary.h !== dominant.h ? secondary.h : dominant.h,
                Math.max(secondary.s, 0.25),
                0.06 + secondary.l * 0.20)

            root._sampledPrimaryColor = root._hslToRgb(accent.h,
                Math.max(accent.s, 0.55),
                Math.max(accent.l, 0.75))

            root._sampledIsDark = dominant.lum < 0.5
            root._hasSampledColor = true
        }
    }


    // ── UI ─────────────────────────────────────────────────────────────────

    fullRepresentation: Item {
        id: full
        Layout.preferredWidth: 200
        Layout.preferredHeight: 200
        Layout.minimumWidth: 80
        Layout.minimumHeight: 60

        readonly property real _ar: full.width / Math.max(1, full.height)
        readonly property string _layout:
            _ar >= 3.0  ? "bar"
          : _ar >= 1.6  ? "wide"
          : _ar <= 0.35 ? "tall"
          : _ar <= 0.85 ? "tallwide"
          :               "square"

        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: plasmoid.configuration.cornerRadius
            roundness: plasmoid.configuration.roundnessX10 / 10
            refractThickness: plasmoid.configuration.refractThickness
            refractIOR: plasmoid.configuration.refractIORx100 / 100
            refractScale: plasmoid.configuration.refractScale
            tint: colors.isGlass && root._hasSampledColor ? root._sampledTint : colors.glassTint
            tintAlpha: colors.isGlass && root._hasSampledColor
                ? Math.max(plasmoid.configuration.tintAlphaPct / 100, 0.15)
                : plasmoid.configuration.tintAlphaPct / 100
            chromaStrength: plasmoid.configuration.chromaStrengthPct / 100
            specStrength: plasmoid.configuration.specStrengthPct / 100
            blurRadius: plasmoid.configuration.blurRadiusPx
            realtimeRefraction: plasmoid.configuration.realtimeRefraction
            fallbackOpacity: colors.glassFallbackOpacity
            solidMode: colors.isSolid
            solidColor: colors.isSolid && root._hasSampledColor ? root._sampledGradientTop : colors.solidBackground
            solidColorBottom: colors.isSolid && root._hasSampledColor ? root._sampledGradientBottom : "transparent"
        }

        SquareLayout {
            anchors.fill: parent
            visible: full._layout === "square"
            colors: colors
            cornerRadius: plasmoid.configuration.cornerRadius
            roundness: plasmoid.configuration.roundnessX10 / 10
            fontFamily: sfRegular.name
            fontFamilyThin: sfThin.name
            track: root.track
            artist: root.artist
            albumArt: root.albumArt
            isPlaying: root.isPlaying
            canGoPrevious: root.canGoPrevious
            canGoNext: root.canGoNext
            canPlay: root.canPlay
            canPause: root.canPause
            position: root.position
            length: root.length
            onTogglePlaying: root.togglePlaying()
            onNextTrack: root.next()
            onPreviousTrack: root.previous()
            onSeek: function(pos) { root.seek(pos) }
            formatTime: root.formatTime
        }

        TallLayout {
            anchors.fill: parent
            visible: full._layout === "tall"
            colors: colors
            accentColor: root._hasSampledColor ? root._sampledPrimaryColor : colors.foreground
            fontFamily: sfRegular.name
            fontFamilyThin: sfThin.name
            track: root.track
            artist: root.artist
            albumArt: root.albumArt
            isPlaying: root.isPlaying
            canGoPrevious: root.canGoPrevious
            canGoNext: root.canGoNext
            canPlay: root.canPlay
            canPause: root.canPause
            position: root.position
            length: root.length
            onTogglePlaying: root.togglePlaying()
            onNextTrack: root.next()
            onPreviousTrack: root.previous()
            onSeek: function(pos) { root.seek(pos) }
            formatTime: root.formatTime
        }

        TallWideLayout {
            anchors.fill: parent
            visible: full._layout === "tallwide"
            colors: colors
            accentColor: root._hasSampledColor ? root._sampledPrimaryColor : colors.foreground
            fontFamily: sfRegular.name
            fontFamilyThin: sfThin.name
            track: root.track
            artist: root.artist
            albumArt: root.albumArt
            isPlaying: root.isPlaying
            canGoPrevious: root.canGoPrevious
            canGoNext: root.canGoNext
            canPlay: root.canPlay
            canPause: root.canPause
            position: root.position
            length: root.length
            onTogglePlaying: root.togglePlaying()
            onNextTrack: root.next()
            onPreviousTrack: root.previous()
            onSeek: function(pos) { root.seek(pos) }
            formatTime: root.formatTime
        }

        WideLayout {
            anchors.fill: parent
            visible: full._layout === "wide"
            colors: colors
            accentColor: root._hasSampledColor ? root._sampledPrimaryColor : colors.foreground
            fontFamily: sfRegular.name
            fontFamilyThin: sfThin.name
            track: root.track
            artist: root.artist
            albumArt: root.albumArt
            isPlaying: root.isPlaying
            canGoPrevious: root.canGoPrevious
            canGoNext: root.canGoNext
            canPlay: root.canPlay
            canPause: root.canPause
            position: root.position
            length: root.length
            onTogglePlaying: root.togglePlaying()
            onNextTrack: root.next()
            onPreviousTrack: root.previous()
            onSeek: function(pos) { root.seek(pos) }
            formatTime: root.formatTime
        }

        BarLayout {
            anchors.fill: parent
            visible: full._layout === "bar"
            colors: colors
            accentColor: root._hasSampledColor ? root._sampledPrimaryColor : colors.foreground
            cornerRadius: plasmoid.configuration.cornerRadius
            fontFamily: sfRegular.name
            fontFamilyThin: sfThin.name
            track: root.track
            artist: root.artist
            albumArt: root.albumArt
            isPlaying: root.isPlaying
            canGoPrevious: root.canGoPrevious
            canGoNext: root.canGoNext
            canPlay: root.canPlay
            canPause: root.canPause
            position: root.position
            length: root.length
            onTogglePlaying: root.togglePlaying()
            onNextTrack: root.next()
            onPreviousTrack: root.previous()
            onSeek: function(pos) { root.seek(pos) }
            formatTime: root.formatTime
        }
    }
}
