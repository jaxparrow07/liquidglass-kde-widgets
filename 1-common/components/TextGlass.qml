import QtQuick
import org.kde.plasma.plasmoid

// Text-shaped liquid-glass background.
//
// Like LiquidGlass.qml, but the glass silhouette is the alpha shape of an
// arbitrary `maskSource` item (typically rendered glyphs) instead of a
// squircle. Edge refraction, chromatic dispersion, and the specular lip run
// along every contour of the masked shape, so each stroke reads as a real
// glass body sitting on the wallpaper.
//
// SDF pipeline (always live — mirrors LiquidGlass's live Kawase pyramid):
//   maskSource -> maskTex (antialiased coverage)
//     -> blur_h -> blur_v   (Gaussian, radius ≈ refractThickness)
//     -> glyph_sdf          (coverage ramp -> signed distance + edge normal)
//   wallpaperTex -> crop -> Dual Kawase blur   (identical to LiquidGlass)
//   glassShader(liquidglasstext): samples backdrop displaced by the glyph SDF
//
// A Gaussian coverage ramp (rather than an exact JFA distance field) keeps the
// chain free of ping-pong ordering hazards and naturally softens glyph edges.
// The ramp's 0.5 isocontour tracks the glyph silhouette; its slope across the
// blur radius gives both the signed distance and the surface normal.
//
// Falls back to a flat tinted glyph fill when the wallpaper containment is
// unavailable (panels, plasmoidviewer) or when solidMode is set.
Item {
    id: glass

    // The item whose ALPHA defines the glass shape. Rendered off-screen
    // (white-on-transparent) by the caller; we capture it into maskTex.
    property Item maskSource: null

    // Glass effect — mirrors LiquidGlass.qml's public API (no radius/roundness;
    // the shape comes from maskSource).
    property real refractThickness: 22
    property real refractIOR: 1.7
    property real refractScale: 45
    property color tint: "#ffffff"
    property real tintAlpha: 0.10
    property real chromaStrength: 0.30

    property real blurRadius: 6

    property bool specEnabled: true
    property real specStrength: 0.70

    property bool realtimeRefraction: false

    property real fallbackOpacity: 0.55

    property bool solidMode: false
    property color solidColor: "#1A1B1E"

    // px span packed into the SDF texture's distance channel. Must comfortably
    // exceed refractThickness so the edge band is fully represented.
    readonly property real _sdfRange: 64.0

    // Gaussian radius used to turn the glyph coverage into a distance ramp.
    // Wide enough to cover the refraction band plus a soft AA shoulder, but
    // kept modest so it doesn't overfill thin strokes (which destabilises the
    // coverage gradient -> normal on tight inner curves).
    readonly property real _sdfBlurPx: Math.max(5.0, glass.refractThickness * 0.8)

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
        if (moved && !realtimeRefraction) wallpaperTex.scheduleUpdate()
    }

    Timer {
        interval: 16
        repeat: true
        running: !glass.solidMode && glass.active
                 && glass.visible && glass.width > 0 && glass.height > 0
        onTriggered: glass.updateGeometry()
    }
    Component.onCompleted: updateGeometry()

    readonly property real _widgetW: Math.max(1, glass.width)
    readonly property real _widgetH: Math.max(1, glass.height)
    readonly property vector2d _texel: Qt.vector2d(1.0 / _widgetW, 1.0 / _widgetH)
    readonly property vector2d _sizePx: Qt.vector2d(_widgetW, _widgetH)

    // =====================================================================
    //  Glyph mask capture + Gaussian distance ramp  (always live)
    // =====================================================================

    ShaderEffectSource {
        id: maskSrc
        anchors.fill: parent
        opacity: 0
        sourceItem: glass.maskSource
        live: true
        hideSource: false
        recursive: false
        smooth: true
        textureSize: Qt.size(Math.round(glass._widgetW), Math.round(glass._widgetH))
    }

    // Separable Gaussian on the mask coverage. radiusPx ≈ refractThickness so
    // the ramp spans the full refraction band.
    ShaderEffect {
        id: maskBlurH
        anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/blur_h.frag.qsb")
        property variant source: maskSrc
        property real radiusPx: glass._sdfBlurPx
        property vector2d sourceSizePx: glass._sizePx
    }
    ShaderEffectSource {
        id: maskBlurHTex; anchors.fill: parent; opacity: 0
        sourceItem: maskBlurH; live: true; hideSource: true; smooth: true
        textureSize: Qt.size(Math.round(glass._widgetW), Math.round(glass._widgetH))
    }
    ShaderEffect {
        id: maskBlurV
        anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/blur_v.frag.qsb")
        property variant source: maskBlurHTex
        property real radiusPx: glass._sdfBlurPx
        property vector2d sourceSizePx: glass._sizePx
    }
    ShaderEffectSource {
        id: maskBlurTex; anchors.fill: parent; opacity: 0
        sourceItem: maskBlurV; live: true; hideSource: true; smooth: true
        textureSize: Qt.size(Math.round(glass._widgetW), Math.round(glass._widgetH))
    }

    // Resolve the blurred coverage ramp into signed distance + edge normal.
    ShaderEffect {
        id: sdfPass
        anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/glyph_sdf.frag.qsb")
        property variant src: maskBlurTex
        property size size: Qt.size(glass._widgetW, glass._widgetH)
        property vector2d texel: glass._texel
        property real sdfRange: glass._sdfRange
        property real fastSDF: 1.0
        // px-per-coverage-unit: the Gaussian spreads the 0/1 step across
        // ~_sdfBlurPx, so a coverage delta of 0.5 ≈ _sdfBlurPx in distance.
        property real rampScale: glass._sdfBlurPx * 2.0
        // Sample the normal gradient over a few px (≈ half the ramp width) so
        // it reads the true slope, not 1-texel noise.
        property real gradStepPx: Math.max(2.0, glass._sdfBlurPx * 0.5)
    }
    ShaderEffectSource {
        id: sdfTexSrc
        anchors.fill: parent; opacity: 0
        sourceItem: sdfPass
        live: true; hideSource: true; smooth: true
        textureSize: Qt.size(Math.round(glass._widgetW), Math.round(glass._widgetH))
    }

    // =====================================================================
    //  Wallpaper capture + Dual Kawase blur (identical to LiquidGlass.qml)
    // =====================================================================

    ShaderEffectSource {
        id: wallpaperTex
        anchors.fill: parent
        opacity: 0
        sourceItem: glass.solidMode ? null : glass.wallpaperItem
        live: !glass.solidMode && glass.realtimeRefraction
        hideSource: false
        recursive: false
        smooth: true
        mipmap: true
        textureMirroring: ShaderEffectSource.MirrorVertically

        onSourceItemChanged: scheduleUpdate()
        Connections {
            target: glass
            function onWidthChanged()  { if (!glass.solidMode && !glass.realtimeRefraction) wallpaperTex.scheduleUpdate() }
            function onHeightChanged() { if (!glass.solidMode && !glass.realtimeRefraction) wallpaperTex.scheduleUpdate() }
        }
    }

    readonly property bool _blurActive: !glass.solidMode && glass.blurRadius > 0 && glass.active

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

    ShaderEffect {
        id: cropPass
        anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/crop.frag.qsb")
        property variant source: wallpaperTex
        property vector2d uvOffset: glass._uvOff
        property vector2d uvScale: glass._uvSc
    }
    ShaderEffectSource {
        id: cropTex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive ? cropPass : null
        live: glass._blurActive; hideSource: true; smooth: true
    }

    ShaderEffect {
        id: down1; anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_down.frag.qsb")
        property variant source: cropTex
        property vector2d halfpixel: Qt.vector2d(0.5 / glass._widgetW, 0.5 / glass._widgetH)
    }
    ShaderEffectSource { id: down1Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive && glass._blurIters >= 1 ? down1 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: Qt.size(Math.max(1, Math.round(glass._widgetW / 2)),
                             Math.max(1, Math.round(glass._widgetH / 2))) }

    ShaderEffect {
        id: down2; anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_down.frag.qsb")
        property variant source: down1Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down1Tex.textureSize.width),
                                                  0.5 / Math.max(1, down1Tex.textureSize.height))
    }
    ShaderEffectSource { id: down2Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive && glass._blurIters >= 2 ? down2 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: Qt.size(Math.max(1, Math.round(glass._widgetW / 4)),
                             Math.max(1, Math.round(glass._widgetH / 4))) }

    ShaderEffect {
        id: down3; anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_down.frag.qsb")
        property variant source: down2Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down2Tex.textureSize.width),
                                                  0.5 / Math.max(1, down2Tex.textureSize.height))
    }
    ShaderEffectSource { id: down3Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive && glass._blurIters >= 3 ? down3 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: Qt.size(Math.max(1, Math.round(glass._widgetW / 8)),
                             Math.max(1, Math.round(glass._widgetH / 8))) }

    ShaderEffect {
        id: down4; anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_down.frag.qsb")
        property variant source: down3Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down3Tex.textureSize.width),
                                                  0.5 / Math.max(1, down3Tex.textureSize.height))
    }
    ShaderEffectSource { id: down4Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive && glass._blurIters >= 4 ? down4 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: Qt.size(Math.max(1, Math.round(glass._widgetW / 16)),
                             Math.max(1, Math.round(glass._widgetH / 16))) }

    ShaderEffect {
        id: down5; anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_down.frag.qsb")
        property variant source: down4Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down4Tex.textureSize.width),
                                                  0.5 / Math.max(1, down4Tex.textureSize.height))
    }
    ShaderEffectSource { id: down5Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive && glass._blurIters >= 5 ? down5 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: Qt.size(Math.max(1, Math.round(glass._widgetW / 32)),
                             Math.max(1, Math.round(glass._widgetH / 32))) }

    ShaderEffect {
        id: down6; anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_down.frag.qsb")
        property variant source: down5Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down5Tex.textureSize.width),
                                                  0.5 / Math.max(1, down5Tex.textureSize.height))
    }
    ShaderEffectSource { id: down6Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive && glass._blurIters >= 6 ? down6 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: Qt.size(Math.max(1, Math.round(glass._widgetW / 64)),
                             Math.max(1, Math.round(glass._widgetH / 64))) }

    ShaderEffect {
        id: up6; anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_up.frag.qsb")
        property variant source: down6Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down5Tex.textureSize.width),
                                                  0.5 / Math.max(1, down5Tex.textureSize.height))
    }
    ShaderEffectSource { id: up6Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive && glass._blurIters >= 6 ? up6 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: down5Tex.textureSize }

    ShaderEffect {
        id: up5; anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_up.frag.qsb")
        property variant source: glass._blurIters >= 6 ? up6Tex : down5Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down4Tex.textureSize.width),
                                                  0.5 / Math.max(1, down4Tex.textureSize.height))
    }
    ShaderEffectSource { id: up5Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive && glass._blurIters >= 5 ? up5 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: down4Tex.textureSize }

    ShaderEffect {
        id: up4; anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_up.frag.qsb")
        property variant source: glass._blurIters >= 5 ? up5Tex : down4Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down3Tex.textureSize.width),
                                                  0.5 / Math.max(1, down3Tex.textureSize.height))
    }
    ShaderEffectSource { id: up4Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive && glass._blurIters >= 4 ? up4 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: down3Tex.textureSize }

    ShaderEffect {
        id: up3; anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_up.frag.qsb")
        property variant source: glass._blurIters >= 4 ? up4Tex : down3Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down2Tex.textureSize.width),
                                                  0.5 / Math.max(1, down2Tex.textureSize.height))
    }
    ShaderEffectSource { id: up3Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive && glass._blurIters >= 3 ? up3 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: down2Tex.textureSize }

    ShaderEffect {
        id: up2; anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_up.frag.qsb")
        property variant source: glass._blurIters >= 3 ? up3Tex : down2Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down1Tex.textureSize.width),
                                                  0.5 / Math.max(1, down1Tex.textureSize.height))
    }
    ShaderEffectSource { id: up2Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive && glass._blurIters >= 2 ? up2 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: down1Tex.textureSize }

    ShaderEffect {
        id: up1; anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_up.frag.qsb")
        property variant source: glass._blurIters >= 2 ? up2Tex : down1Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / glass._widgetW, 0.5 / glass._widgetH)
    }
    ShaderEffectSource { id: up1Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurActive ? up1 : null
        live: glass._blurActive; hideSource: true; smooth: true
        textureSize: Qt.size(Math.round(glass._widgetW), Math.round(glass._widgetH)) }

    // =====================================================================
    //  Final glass shader (text-shaped)
    // =====================================================================

    // True when glass mode is requested but no wallpaper is available to
    // refract (plasmoidviewer, panels) — render a translucent glyph fill.
    readonly property bool _fallback: !glass.solidMode && !glass.active

    ShaderEffect {
        id: glassShader
        anchors.fill: parent
        visible: true
        fragmentShader: Qt.resolvedUrl("shaders/liquidglasstext.frag.qsb")

        property variant backdrop: glass._blurActive ? up1Tex : wallpaperTex
        property variant sdfTex: sdfTexSrc
        property variant maskTex: maskSrc
        property size size: Qt.size(glass._widgetW, glass._widgetH)
        property real refractThickness: glass.solidMode ? 0.0 : glass.refractThickness
        property real refractIOR: glass.refractIOR
        property real refractScale: glass.solidMode ? 0.0 : glass.refractScale
        property real chromaStrength: glass.solidMode ? 0.0 : glass.chromaStrength
        property real sdfRange: glass._sdfRange
        property real solidMode: glass.solidMode ? 1.0 : 0.0
        property real fallbackMode: glass._fallback ? 1.0 : 0.0
        property real fallbackOpacity: glass.fallbackOpacity
        property vector4d tint: glass.solidMode
            ? Qt.vector4d(glass.solidColor.r, glass.solidColor.g, glass.solidColor.b, 1.0)
            : Qt.vector4d(glass.tint.r, glass.tint.g, glass.tint.b, glass.tintAlpha)
        property real specStrength: glass.specEnabled ? glass.specStrength : 0.0

        property vector2d uvOffset: glass._blurActive
            ? Qt.vector2d(0, 0) : glass._uvOff
        property vector2d uvScale: glass._blurActive
            ? Qt.vector2d(1, 1) : glass._uvSc
    }
}
