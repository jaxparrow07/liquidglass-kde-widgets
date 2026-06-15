import QtQuick
import org.kde.plasma.plasmoid

// Reusable frosted/liquid-glass background.
// Place inside a PlasmoidItem, anchors.fill: parent.
//
// Pipeline:
//   wallpaperTex -> crop (extract widget region)
//     -> Dual Kawase downsample (1-6 levels, halving resolution each)
//     -> Dual Kawase upsample (back to full resolution)
//     -> glassShader (refraction + chroma + tint)
//
// The crop shader maps wallpaper UV to widget-local UV so the blur
// passes operate in widget pixel space. blurRadius controls the number
// of downsample/upsample iterations (each level doubles the effective
// blur reach). When blurRadius <= 0 the crop/blur chain is inert and
// the glass shader samples wallpaperTex directly with uvOffset/uvScale.
//
// Falls back to a flat translucent rounded rect when wallpaperGraphicsObject
// is null or zero-size (panels, plasmoidviewer).
Item {
    id: glass

    // Shape
    property real radius: 100
    // Superellipse exponent: 2 = plain rounded rect, 5.5 ≈ iOS squircle
    property real roundness: 7.5

    // Glass effect — Snell-on-a-dome refraction through an edge band.
    // refractThickness is the width of that band in pixels. refractIOR is
    // the glass index of refraction (1.0 = none, 1.4 ≈ real glass, higher
    // exaggerates). refractScale is a user-facing strength multiplier on
    // top of Snell — cranked up vs. the reference because our coordinates
    // are widget pixels, not normalized units.
    property real refractThickness: 35
    property real refractIOR: 1.7
    property real refractScale: 65
    property color tint: "#ffffff"
    property real tintAlpha: 0.10
    property real chromaStrength: 0.30

    // Blur spread in widget pixels; 0 = disabled.
    property real blurRadius: 6

    // Border specular (free-following primary + antipodal secondary).
    property bool specEnabled: true
    property real specStrength: 0.70

    // When false, the wallpaper is only re-captured on geometry changes
    // (recommended for static wallpapers — saves GPU per frame). Turn on
    // for animated / video wallpapers that need continuous updates.
    property bool realtimeRefraction: false

    property real fallbackOpacity: 0.55

    // Solid mode: skip wallpaper capture and refraction; render an opaque
    // squircle filled with `solidColor`. The squircle silhouette + corner
    // specular still render via the same shader (tint forced opaque), so
    // the macOS material feel is preserved.
    property bool solidMode: false
    property color solidColor: "#1A1B1E"
    property color solidColorBottom: "transparent"

    property vector4d overlayDarken: Qt.vector4d(0, 0, 0, 0)

    readonly property var wallpaperItem: {
        const c = Plasmoid.containment
        if (!c) return null
        const w = c.wallpaperGraphicsObject
        if (!w) return null
        return findRenderableSource(w)
    }

    readonly property bool active: wallpaperItem !== null
                                   && wallpaperItem.width > 0
                                   && wallpaperItem.height > 0

    function isLoader(n) {
        return n && n.sourceComponent !== undefined && n.item !== undefined
    }
    // Pick the topmost sized item. ShaderEffectSource captures the whole
    // subtree, so descending into children is only needed when the outer
    // wrapper has no size yet (e.g. a Loader still resolving). Drilling
    // past a sized parent caused us to land on hidden iChannel Images
    // inside shader-wallpaper plugins (online.knowmad.shaderwallpaper).
    function findRenderableSource(node) {
        if (!node) return null
        if (isLoader(node)) return findRenderableSource(node.item)
        if (node.width > 0 && node.height > 0) return node
        if (node.children && node.children.length > 0) {
            for (var i = 0; i < node.children.length; i++) {
                const inner = findRenderableSource(node.children[i])
                if (inner) return inner
            }
        }
        return null
    }

    property real _offX: 0
    property real _offY: 0
    function updateGeometry() {
        if (!wallpaperItem) return
        const p = glass.mapToItem(wallpaperItem, 0, 0)
        let moved = false
        if (p.x !== _offX) { _offX = p.x; moved = true }
        if (p.y !== _offY) { _offY = p.y; moved = true }
        // If realtime is off, force a one-shot backdrop recapture so the
        // sampled wallpaper stays aligned after the widget moves.
        if (moved && !realtimeRefraction) wallpaperTex.scheduleUpdate()
    }

    // --- Mouse tracking for specular highlight ---
    // _mouseU/_mouseV are in widget-local UV (0..1). (-1,-1) means no hover.
    property real _mouseU: -1
    property real _mouseV: -1
    property real _mouseFade: 0

    Behavior on _mouseFade {
        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: glass.specEnabled
        acceptedButtons: Qt.NoButton   // never consume clicks
        propagateComposedEvents: true

        onPositionChanged: (mouse) => {
            glass._mouseU = mouse.x / Math.max(1, glass.width)
            glass._mouseV = mouse.y / Math.max(1, glass.height)
            glass._mouseFade = 1
        }
        onEntered: glass._mouseFade = 1
        onExited: {
            glass._mouseFade = 0
            glass._mouseU = -1
            glass._mouseV = -1
        }
    }
    Timer {
        interval: 16
        repeat: true
        // Solid mode doesn't need geometry updates (no wallpaper sample),
        // but we still want the timer disabled until the widget has size.
        running: !glass.solidMode && glass.active
                 && glass.visible && glass.width > 0 && glass.height > 0
        onTriggered: glass.updateGeometry()
    }
    Component.onCompleted: updateGeometry()

    // --- Wallpaper capture ---

    ShaderEffectSource {
        id: wallpaperTex
        anchors.fill: parent
        opacity: 0
        sourceItem: glass.solidMode ? null : glass.wallpaperItem
        live: !glass.solidMode && glass.realtimeRefraction
        hideSource: false
        recursive: false
        smooth: true
        // Mipmap the full-res capture so the crop pass (which minifies a
        // large wallpaper — e.g. a 4K video frame — into the small
        // widget-sized texture) samples from a pre-filtered mip level
        // instead of undersampling with a single bilinear tap. Without
        // this, high-res / detailed wallpapers alias and shimmer, reading
        // as a "cheap", low-quality blur, especially at low blur radius
        // where the shallow Kawase pyramid can't mask the aliasing.
        mipmap: true
        textureMirroring: ShaderEffectSource.MirrorVertically

        onSourceItemChanged: scheduleUpdate()
        Connections {
            target: glass
            function onWidthChanged()  { if (!glass.solidMode && !glass.realtimeRefraction) wallpaperTex.scheduleUpdate() }
            function onHeightChanged() { if (!glass.solidMode && !glass.realtimeRefraction) wallpaperTex.scheduleUpdate() }
        }
    }

    // --- Frosted-glass blur pipeline (Dual Kawase) ---
    //
    // crop → downsample 1..N → upsample N..1
    //
    // The crop shader extracts the widget's wallpaper region into a
    // widget-sized texture. Dual Kawase then downsamples through a
    // resolution pyramid (each level halves dimensions, 5 taps) and
    // upsamples back (9 taps per level). blurRadius controls the number
    // of levels (1-6). This gives smooth, artifact-free blur at any
    // radius up to ~128px with only 5-9 taps per pass.
    //
    // When blurRadius <= 0 or in solid mode, the crop/blur chain is
    // inert and the glass shader samples wallpaperTex directly with
    // the standard uvOffset/uvScale.

    readonly property bool _blurActive: !glass.solidMode && glass.blurRadius > 0 && glass.active

    // Dual Kawase: number of downsample iterations (each doubles blur reach).
    // radius ~2→1, ~4→2, ~8→3, ~16→4, ~32→5, ~64→6, ~100→6.
    //
    // The two deepest levels (widget/32, widget/64) are only a handful of
    // texels wide. On a STATIC wallpaper the up-pass smooths them so they're
    // invisible. But on a moving (video) wallpaper those tiny levels pump
    // frame-to-frame and read as a blocky "mosaic" in motion. So in realtime
    // mode we cap the pyramid at 4 levels (smallest texture = widget/16),
    // trading a little max blur reach for motion smoothness. Static
    // wallpapers keep the full 6-level table for maximum reach.
    readonly property int _maxBlurIters: glass.realtimeRefraction ? 4 : 6
    readonly property int _blurIters: {
        if (!_blurActive) return 0;
        var r = glass.blurRadius;
        var iters;
        if (r <= 2) iters = 1;
        else if (r <= 4) iters = 2;
        else if (r <= 8) iters = 3;
        else if (r <= 16) iters = 4;
        else if (r <= 32) iters = 5;
        else iters = 6;
        return Math.min(iters, _maxBlurIters);
    }

    readonly property vector2d _uvOff: glass.active
        ? Qt.vector2d(glass._offX / glass.wallpaperItem.width,
                      glass._offY / glass.wallpaperItem.height)
        : Qt.vector2d(0, 0)
    readonly property vector2d _uvSc: glass.active
        ? Qt.vector2d(glass.width  / glass.wallpaperItem.width,
                      glass.height / glass.wallpaperItem.height)
        : Qt.vector2d(1, 1)

    readonly property real _widgetW: Math.max(1, glass.width)
    readonly property real _widgetH: Math.max(1, glass.height)

    ShaderEffect {
        id: cropPass
        anchors.fill: parent
        visible: false
        fragmentShader: Qt.resolvedUrl("shaders/crop.frag.qsb")
        property variant source: wallpaperTex
        property vector2d uvOffset: glass._uvOff
        property vector2d uvScale: glass._uvSc
    }
    ShaderEffectSource {
        id: cropTex
        anchors.fill: parent
        opacity: 0
        sourceItem: glass._blurActive ? cropPass : null
        live: glass._blurActive
        hideSource: true
        smooth: true
    }

    // --- Dual Kawase blur: downsample chain (up to 6 levels) ---

    ShaderEffect {
        id: down1
        anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_down.frag.qsb")
        property variant source: cropTex
        property vector2d halfpixel: Qt.vector2d(0.5 / glass._widgetW, 0.5 / glass._widgetH)
    }
    ShaderEffectSource {
        id: down1Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive && glass._blurIters >= 1 ? down1 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: Qt.size(Math.max(1, Math.round(glass._widgetW / 2)),
                             Math.max(1, Math.round(glass._widgetH / 2)))
    }

    ShaderEffect {
        id: down2
        anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_down.frag.qsb")
        property variant source: down1Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down1Tex.textureSize.width),
                                                  0.5 / Math.max(1, down1Tex.textureSize.height))
    }
    ShaderEffectSource {
        id: down2Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive && glass._blurIters >= 2 ? down2 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: Qt.size(Math.max(1, Math.round(glass._widgetW / 4)),
                             Math.max(1, Math.round(glass._widgetH / 4)))
    }

    ShaderEffect {
        id: down3
        anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_down.frag.qsb")
        property variant source: down2Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down2Tex.textureSize.width),
                                                  0.5 / Math.max(1, down2Tex.textureSize.height))
    }
    ShaderEffectSource {
        id: down3Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive && glass._blurIters >= 3 ? down3 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: Qt.size(Math.max(1, Math.round(glass._widgetW / 8)),
                             Math.max(1, Math.round(glass._widgetH / 8)))
    }

    ShaderEffect {
        id: down4
        anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_down.frag.qsb")
        property variant source: down3Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down3Tex.textureSize.width),
                                                  0.5 / Math.max(1, down3Tex.textureSize.height))
    }
    ShaderEffectSource {
        id: down4Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive && glass._blurIters >= 4 ? down4 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: Qt.size(Math.max(1, Math.round(glass._widgetW / 16)),
                             Math.max(1, Math.round(glass._widgetH / 16)))
    }

    ShaderEffect {
        id: down5
        anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_down.frag.qsb")
        property variant source: down4Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down4Tex.textureSize.width),
                                                  0.5 / Math.max(1, down4Tex.textureSize.height))
    }
    ShaderEffectSource {
        id: down5Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive && glass._blurIters >= 5 ? down5 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: Qt.size(Math.max(1, Math.round(glass._widgetW / 32)),
                             Math.max(1, Math.round(glass._widgetH / 32)))
    }

    ShaderEffect {
        id: down6
        anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_down.frag.qsb")
        property variant source: down5Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down5Tex.textureSize.width),
                                                  0.5 / Math.max(1, down5Tex.textureSize.height))
    }
    ShaderEffectSource {
        id: down6Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive && glass._blurIters >= 6 ? down6 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: Qt.size(Math.max(1, Math.round(glass._widgetW / 64)),
                             Math.max(1, Math.round(glass._widgetH / 64)))
    }

    // --- Dual Kawase blur: upsample chain (mirrors downsample) ---

    // Bottom of the pyramid — picks the deepest downsample level reached.
    readonly property var _bottomTex: _blurIters >= 6 ? down6Tex :
                                      _blurIters >= 5 ? down5Tex :
                                      _blurIters >= 4 ? down4Tex :
                                      _blurIters >= 3 ? down3Tex :
                                      _blurIters >= 2 ? down2Tex : down1Tex

    ShaderEffect {
        id: up6
        anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_up.frag.qsb")
        property variant source: down6Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down5Tex.textureSize.width),
                                                  0.5 / Math.max(1, down5Tex.textureSize.height))
    }
    ShaderEffectSource {
        id: up6Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive && glass._blurIters >= 6 ? up6 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: down5Tex.textureSize
    }

    ShaderEffect {
        id: up5
        anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_up.frag.qsb")
        property variant source: glass._blurIters >= 6 ? up6Tex : down5Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down4Tex.textureSize.width),
                                                  0.5 / Math.max(1, down4Tex.textureSize.height))
    }
    ShaderEffectSource {
        id: up5Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive && glass._blurIters >= 5 ? up5 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: down4Tex.textureSize
    }

    ShaderEffect {
        id: up4
        anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_up.frag.qsb")
        property variant source: glass._blurIters >= 5 ? up5Tex : down4Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down3Tex.textureSize.width),
                                                  0.5 / Math.max(1, down3Tex.textureSize.height))
    }
    ShaderEffectSource {
        id: up4Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive && glass._blurIters >= 4 ? up4 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: down3Tex.textureSize
    }

    ShaderEffect {
        id: up3
        anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_up.frag.qsb")
        property variant source: glass._blurIters >= 4 ? up4Tex : down3Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down2Tex.textureSize.width),
                                                  0.5 / Math.max(1, down2Tex.textureSize.height))
    }
    ShaderEffectSource {
        id: up3Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive && glass._blurIters >= 3 ? up3 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: down2Tex.textureSize
    }

    ShaderEffect {
        id: up2
        anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_up.frag.qsb")
        property variant source: glass._blurIters >= 3 ? up3Tex : down2Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down1Tex.textureSize.width),
                                                  0.5 / Math.max(1, down1Tex.textureSize.height))
    }
    ShaderEffectSource {
        id: up2Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive && glass._blurIters >= 2 ? up2 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: down1Tex.textureSize
    }

    ShaderEffect {
        id: up1
        anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_up.frag.qsb")
        property variant source: glass._blurIters >= 2 ? up2Tex : down1Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / glass._widgetW, 0.5 / glass._widgetH)
    }
    ShaderEffectSource {
        id: up1Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive ? up1 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: Qt.size(Math.round(glass._widgetW), Math.round(glass._widgetH))
    }

    // --- Glass shader (refraction + chroma + tint + specular + mask) ---
    //
    // When blur is active, backdrop is the blurred crop in widget-local
    // UV (uvOffset=0, uvScale=1). Refraction displaces into the blurred
    // image. When blur is off, falls back to wallpaperTex with the
    // standard offset/scale mapping.

    ShaderEffect {
        id: glassShader
        anchors.fill: parent
        visible: glass.solidMode || glass.active
        fragmentShader: Qt.resolvedUrl("shaders/liquidglass.frag.qsb")

        property variant backdrop: glass._blurActive ? up1Tex : wallpaperTex
        property size size: Qt.size(glass._widgetW, glass._widgetH)
        property real radius: glass.radius
        property real roundness: glass.roundness
        property real refractThickness: glass.solidMode ? 0.0 : glass.refractThickness
        property real refractIOR: glass.refractIOR
        property real refractScale: glass.solidMode ? 0.0 : glass.refractScale
        property real chromaStrength: glass.solidMode ? 0.0 : glass.chromaStrength
        property vector4d tint: glass.solidMode
            ? Qt.vector4d(glass.solidColor.r, glass.solidColor.g, glass.solidColor.b, 1.0)
            : Qt.vector4d(glass.tint.r, glass.tint.g, glass.tint.b, glass.tintAlpha)
        property vector4d tintBottom: glass.solidMode && glass.solidColorBottom.a > 0
            ? Qt.vector4d(glass.solidColorBottom.r, glass.solidColorBottom.g, glass.solidColorBottom.b, 1.0)
            : Qt.vector4d(0, 0, 0, 0)

        property vector2d mousePos: Qt.vector2d(glass._mouseU, glass._mouseV)
        property real mouseFade: glass._mouseFade
        property real specStrength: glass.specEnabled ? glass.specStrength : 0.0
        property vector4d overlayDarken: glass.overlayDarken

        property vector2d uvOffset: glass._blurActive
            ? Qt.vector2d(0, 0) : glass._uvOff
        property vector2d uvScale: glass._blurActive
            ? Qt.vector2d(1, 1) : glass._uvSc
    }

    // --- Fallback ---
    // Used when the wallpaper containment is unavailable (panels,
    // plasmoidviewer) AND we're in glass mode. In solid mode the shader
    // above already renders an opaque tinted squircle, so no fallback
    // needed.

    Rectangle {
        id: fallback
        anchors.fill: parent
        visible: !glass.solidMode && !glass.active
        color: glass.tint
        opacity: glass.fallbackOpacity
        radius: glass.radius
    }
}
