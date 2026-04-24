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
    property real radius: 100
    // Superellipse exponent: 2 = plain rounded rect, 5.5 ≈ iOS squircle
    property real roundness: 7.5

    // Glass effect — Snell-on-a-dome refraction through an edge band.
    // refractThickness is the width of that band in pixels. refractIOR is
    // the glass index of refraction (1.0 = none, 1.4 ≈ real glass, higher
    // exaggerates). refractScale is a user-facing strength multiplier on
    // top of Snell — cranked up vs. the reference because our coordinates
    // are widget pixels, not normalized units.
    property real refractThickness: 30
    property real refractIOR: 1.6
    property real refractScale: 65
    property color tint: "#ffffff"
    property real tintAlpha: 0.15
    property real chromaStrength: 0.20

    // Corner border specular (dominant + diagonal-opposite corners).
    property bool specEnabled: true
    property real specStrength: 0.70

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
        property real roundness: glass.roundness
        property real refractThickness: glass.refractThickness
        property real refractIOR: glass.refractIOR
        property real refractScale: glass.refractScale
        property real chromaStrength: glass.chromaStrength
        property vector4d tint: Qt.vector4d(glass.tint.r, glass.tint.g, glass.tint.b, glass.tintAlpha)

        property vector2d mousePos: Qt.vector2d(glass._mouseU, glass._mouseV)
        property real mouseFade: glass._mouseFade
        property real specStrength: glass.specEnabled ? glass.specStrength : 0.0

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
