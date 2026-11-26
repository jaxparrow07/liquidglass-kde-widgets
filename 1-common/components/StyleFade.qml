import QtQuick

// Cross-fades a widget between Glass and Solid. Place it next to the
// LiquidGlass item, as a child of the item to fade:
//   StyleFade { styleColors: colors; duration: plasmoid.configuration.styleFadeMs }
// When the style changes, it snapshots the parent first, lets MacOSColors
// switch, then fades the snapshot out over the new style. A duration of 0
// turns the fade off.
Item {
    id: fade

    property QtObject styleColors: null
    property int duration: 200

    anchors.fill: parent
    z: 1000

    property bool _grabbing: false

    Image {
        id: snapshot
        anchors.fill: parent
        opacity: 0
        visible: opacity > 0
        cache: false
    }

    NumberAnimation {
        id: fadeOut
        target: snapshot
        property: "opacity"
        from: 1
        to: 0
        duration: fade.duration
        easing.type: Easing.Linear
        onFinished: snapshot.source = ""
    }

    // grabToImage() doesn't always call back (e.g. while the scene isn't
    // rendering). Switch without the fade rather than stay stuck.
    Timer {
        id: grabTimeout
        interval: 300
        onTriggered: {
            fade._grabbing = false
            fade._apply()
        }
    }

    function _apply() {
        fade.styleColors.isGlass = fade.styleColors.wantGlass
    }

    // Called by MacOSColors when wantGlass changes.
    function run() {
        if (_grabbing) return   // the pending grab applies the latest wantGlass
        const target = fade.parent
        if (duration <= 0 || !target || target.width <= 0 || target.height <= 0 || !target.visible) {
            _apply()
            return
        }
        _grabbing = true
        grabTimeout.restart()
        const ok = target.grabToImage(function (result) {
            if (!fade._grabbing) return   // timed out, already switched
            grabTimeout.stop()
            fade._grabbing = false
            // Focus flipped back during the grab: nothing to fade.
            if (fade.styleColors.wantGlass === fade.styleColors.isGlass) return
            snapshot.source = result.url
            fadeOut.stop()
            snapshot.opacity = 1
            fade._apply()
            fadeOut.start()
        })
        if (!ok) {
            grabTimeout.stop()
            _grabbing = false
            _apply()
        }
    }

    Component.onCompleted: if (styleColors) styleColors.fader = fade
    Component.onDestruction: if (styleColors && styleColors.fader === fade) styleColors.fader = null
}
