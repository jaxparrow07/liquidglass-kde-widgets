import QtQuick
import org.kde.plasma.plasmoid

// Reusable frosted/liquid-glass background.
// Place inside a PlasmoidItem, anchors.fill: parent.
//
// Current pipeline (blur disabled):
//   wallpaperTex (ShaderEffectSource of the wallpaper item)
//     -> glassShader (refraction + chromatic aberration + tint + AA mask)
//
// Blur is a TODO — the separable-gaussian version had coord mismatches
// between downscaled intermediates and the final UV math.
//
// Falls back to a flat translucent rounded rect when wallpaperGraphicsObject
// is null or zero-size (panels, plasmoidviewer).
Item {
    id: glass

    // Shape
    property real radius: 22

    // Glass effect — Snell-on-a-dome refraction through an edge band.
    // refractThickness is the width of that band in pixels. refractIOR is
    // the glass index of refraction (1.0 = none, 1.4 ≈ real glass, higher
    // exaggerates). refractScale is a user-facing strength multiplier on
    // top of Snell — cranked up vs. the reference because our coordinates
    // are widget pixels, not normalized units.
    property real refractThickness: 22
    property real refractIOR: 1.4
    property real refractScale: 60
    property color tint: "#ffffff"
    property real tintAlpha: 0.18
    property real chromaStrength: 0.5

    // Placeholder for blur (currently disabled in the pipeline)
    property real blurRadiusPx: 32

    property real fallbackOpacity: 0.55

    property bool debug: false

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
        if (node.children && node.children.length > 0) {
            for (var i = 0; i < node.children.length; i++) {
                const inner = findRenderableSource(node.children[i])
                if (inner) return inner
            }
        }
        if (node.width > 0 && node.height > 0) return node
        return null
    }

    property real _offX: 0
    property real _offY: 0
    function updateGeometry() {
        if (!wallpaperItem) return
        const p = glass.mapToItem(wallpaperItem, 0, 0)
        if (p.x !== _offX) _offX = p.x
        if (p.y !== _offY) _offY = p.y
    }
    Timer {
        interval: 16
        repeat: true
        running: glass.active && glass.visible && glass.width > 0 && glass.height > 0
        onTriggered: glass.updateGeometry()
    }
    Component.onCompleted: updateGeometry()

    // --- Single pass: direct wallpaper capture (blur disabled for now) ---
    //
    // The blur pipeline (H -> V -> H -> V, downsampled 4x) had coordinate
    // mismatches between the downscaled intermediate and the final glass
    // shader's uvOffset/uvScale. Disabled until we untangle it. The glass
    // shader now samples wallpaperTex directly and does refraction +
    // chromatic aberration only.

    ShaderEffectSource {
        id: wallpaperTex
        anchors.fill: parent
        opacity: 0
        sourceItem: glass.wallpaperItem
        live: true
        hideSource: false
        recursive: false
        smooth: true
        mipmap: false
        textureMirroring: ShaderEffectSource.MirrorVertically
    }

    // --- Pass 4: glass (refraction + chroma + tint + rim + mask) ---

    ShaderEffect {
        id: glassShader
        anchors.fill: parent
        visible: glass.active
        fragmentShader: Qt.resolvedUrl("shaders/liquidglass.frag.qsb")

        property variant backdrop: wallpaperTex
        property size size: Qt.size(Math.max(1, glass.width), Math.max(1, glass.height))
        property real radius: glass.radius
        property real refractThickness: glass.refractThickness
        property real refractIOR: glass.refractIOR
        property real refractScale: glass.refractScale
        property real chromaStrength: glass.chromaStrength
        property vector4d tint: Qt.vector4d(glass.tint.r, glass.tint.g, glass.tint.b, glass.tintAlpha)

        property vector2d uvOffset: glass.active
            ? Qt.vector2d(glass._offX / glass.wallpaperItem.width,
                          glass._offY / glass.wallpaperItem.height)
            : Qt.vector2d(0, 0)
        property vector2d uvScale: glass.active
            ? Qt.vector2d(glass.width  / glass.wallpaperItem.width,
                          glass.height / glass.wallpaperItem.height)
            : Qt.vector2d(1, 1)
    }

    // --- Fallback ---

    Rectangle {
        id: fallback
        anchors.fill: parent
        visible: !glass.active
        color: glass.tint
        opacity: glass.fallbackOpacity
        radius: glass.radius
    }
}
