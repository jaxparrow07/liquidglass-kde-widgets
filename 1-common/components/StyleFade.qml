import QtQuick

// Cross-fades a widget between Glass and Solid. Place it next to the
// LiquidGlass item, as a child of the item to fade:
//   StyleFade { styleColors: colors }
// When the style changes, it snapshots the parent first, lets MacOSColors
// switch, then fades the snapshot out over the new style.
Item {
    id: fade

    property QtObject styleColors: null
    property int duration: 400

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
        easing.type: Easing.InOutQuad
        onFinished: snapshot.source = ""
    }

    function _apply() {
        fade.styleColors.isGlass = fade.styleColors.wantGlass
    }

    // Called by MacOSColors when wantGlass changes.
    function run() {
        if (_grabbing) return
        const target = fade.parent
        if (!target || target.width <= 0 || target.height <= 0 || !target.visible) {
            _apply()
            return
        }
        _grabbing = true
        const ok = target.grabToImage(function (result) {
            fade._grabbing = false
            snapshot.source = result.url
            fadeOut.stop()
            snapshot.opacity = 1
            fade._apply()
            fadeOut.start()
        })
        if (!ok) {
            _grabbing = false
            _apply()
        }
    }

    Component.onCompleted: if (styleColors) styleColors.fader = fade
    Component.onDestruction: if (styleColors && styleColors.fader === fade) styleColors.fader = null
}
