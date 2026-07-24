import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "components"

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    MacOSColors {
        id: colors
        styleMode: plasmoid.configuration.styleMode
        appearance: plasmoid.configuration.appearance
    }

    // Light only ever applies in Solid mode — Glass is always dark (white
    // content) so the appearance setting never recolors glass text/ticks.
    readonly property bool _realLight: !colors.isGlass
        && (plasmoid.configuration.appearance === 1
            || (plasmoid.configuration.appearance === 2 && !colors.systemIsDark))
    readonly property color _dialColor: _realLight ? "#000000" : "#ffffff"

    FontLoader {
        id: sfProRounded
        source: Qt.resolvedUrl("../fonts/sf_pro_rounded.otf")
    }

    property real _secondAngle: 0
    property real _minuteAngle: 0
    property real _hourAngle: 0

    Timer {
        id: frameTimer
        interval: 16
        repeat: true
        running: true
        onTriggered: {
            const now = Date.now()
            const d = new Date(now)
            const sec = d.getSeconds() + d.getMilliseconds() / 1000
            const min = d.getMinutes() + sec / 60
            const hr  = (d.getHours() % 12) + min / 60
            root._secondAngle = sec / 60 * 360
            root._minuteAngle = min / 60 * 360
            root._hourAngle   = hr / 12 * 360
        }
        Component.onCompleted: triggered()
    }

    fullRepresentation: Item {
        id: full
        Layout.preferredWidth:  full.width  > 0 ? full.width  : 200
        Layout.preferredHeight: full.height > 0 ? full.height : 200
        Layout.minimumWidth: 160
        Layout.minimumHeight: 160

        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: plasmoid.configuration.cornerRadius
            roundness: plasmoid.configuration.roundnessX10 / 10
            refractThickness: plasmoid.configuration.refractThickness
            refractIOR: plasmoid.configuration.refractIORx100 / 100
            refractScale: plasmoid.configuration.refractScale
            tint: colors.glassTint
            tintAlpha: plasmoid.configuration.tintAlphaPct / 100
            chromaStrength: plasmoid.configuration.chromaStrengthPct / 100
            specStrength: plasmoid.configuration.specStrengthPct / 100
            blurRadius: plasmoid.configuration.blurRadiusPx
            realtimeRefraction: plasmoid.configuration.realtimeRefraction
            fallbackOpacity: colors.glassFallbackOpacity
            // Solid style keeps the glass material as the background squircle
            // by default; only "Fully opaque background" reverts to a flat fill.
            solidMode: colors.isSolid && plasmoid.configuration.opaqueBackground
            // Opaque card is always the dark fill, even in light mode.
            solidColor: "#1A1B1E"
        }

        // Clock face area inset from the glass squircle edge
        Item {
            id: face
            anchors.fill: parent
            anchors.margins: Math.min(full.width, full.height) * 0.08

            readonly property real r: Math.min(width, height) / 2
            readonly property real cx: width / 2
            readonly property real cy: height / 2

            Rectangle {
                id: faceBackground
                width: Math.min(parent.width, parent.height)
                height: width
                anchors.centerIn: parent
                radius: width / 2
                // Solid style: the clock plate is always a solid opaque circle
                // (white in light, #343436 in dark) — it does NOT go translucent
                // when the background squircle is set to the glass material.
                // Glass style keeps the original translucent disc.
                color: colors.isGlass
                    ? Qt.rgba(1, 1, 1, 0.20)
                    : (root._realLight ? "#ffffff" : "#343436")
            }

            // --- Tick marks (pill-shaped, uniform width) ---
            Canvas {
                id: tickCanvas
                anchors.fill: parent
                renderStrategy: Canvas.Immediate

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx = width / 2
                    const cy = height / 2
                    const r  = Math.min(width, height) / 2

                    const tickW   = r * 0.020
                    const tickLen = r * 0.09
                    const hw      = tickW / 2
                    const outerR  = r - tickW * 2   // gap from circle = 2x tick width
                    const innerR  = outerR - tickLen

                    ctx.save()
                    ctx.translate(cx, cy)

                    for (let i = 0; i < 60; i++) {
                        const isMajor = (i % 5 === 0)
                        const alpha   = isMajor ? 0.75 : 0.30
                        // Dial ticks track real light/dark (black on light,
                        // white on dark) in every style, glass included.
                        ctx.fillStyle = Qt.rgba(
                            root._dialColor.r,
                            root._dialColor.g,
                            root._dialColor.b,
                            alpha
                        )

                        const angle = i * 6 * Math.PI / 180

                        ctx.save()
                        ctx.rotate(angle)

                        // Pill-shaped tick: rounded rect along the radial axis
                        const x = -hw
                        const y = -outerR
                        const w = tickW
                        const h = tickLen
                        ctx.beginPath()
                        ctx.moveTo(x + hw, y)
                        ctx.arcTo(x + w, y,     x + w, y + h, hw)
                        ctx.arcTo(x + w, y + h, x,     y + h, hw)
                        ctx.arcTo(x,     y + h, x,     y,     hw)
                        ctx.arcTo(x,     y,     x + w, y,     hw)
                        ctx.closePath()
                        ctx.fill()

                        ctx.restore()
                    }

                    ctx.restore()
                }

                Connections {
                    target: root
                    function on_dialColorChanged() { tickCanvas.requestPaint() }
                }

                onWidthChanged:  requestPaint()
                onHeightChanged: requestPaint()
            }

            // --- Hour numbers ---
            Repeater {
                model: 12

                delegate: Text {
                    id: numLabel
                    required property int index
                    readonly property int num: index === 0 ? 12 : index
                    readonly property real dist: face.r * 0.72
                    readonly property real angle: (num / 12) * 2 * Math.PI
                    x: face.cx + Math.sin(angle) * dist - width  / 2
                    y: face.cy - Math.cos(angle) * dist - height / 2
                    text: num.toString()
                    font.family: sfProRounded.name
                    font.pixelSize: Math.max(8, face.r * 0.17)
                    font.weight: Font.Medium
                    color: colors.foreground
                    opacity: colors.isGlass ? 0.85 : 1.0
                }
            }

            // Thin stem from pivot, then a wider pill with fully rounded ends.
            function _drawHand(ctx, angleDeg, totalLen, stemEnd, stemW, pillW, color) {
                ctx.save()
                ctx.rotate(angleDeg * Math.PI / 180)
                ctx.fillStyle = color

                const sw2 = stemW / 2

                // Stem: rect from center, hidden behind pivot circle at base
                ctx.beginPath()
                ctx.rect(-sw2, -stemEnd, stemW, stemEnd)
                ctx.fill()

                // Pill: fully rounded capsule from -stemEnd to -totalLen
                const pw2 = pillW / 2
                const pr  = pw2
                const pillTop    = -totalLen + pr
                const pillBottom = -stemEnd  - pr

                ctx.beginPath()
                ctx.moveTo(pw2, pillBottom)
                ctx.lineTo(pw2, pillTop)
                ctx.arc(0, pillTop, pr, 0, Math.PI, true)
                ctx.lineTo(-pw2, pillBottom)
                ctx.arc(0, pillBottom, pr, Math.PI, 0, true)
                ctx.closePath()
                ctx.fill()

                ctx.restore()
            }

            // --- All hands drawn in a single canvas to avoid per-canvas rotation mess ---
            Canvas {
                id: handsCanvas
                anchors.fill: parent
                z: 8
                renderStrategy: Canvas.Immediate

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx = width / 2
                    const cy = height / 2
                    const r  = Math.min(width, height) / 2

                    ctx.save()
                    ctx.translate(cx, cy)

                    const handColor = Qt.rgba(
                        colors.foreground.r, colors.foreground.g, colors.foreground.b,
                        colors.isGlass ? 0.92 : 1.0
                    )

                    const tickW   = r * 0.020
                    const tickLen = r * 0.09
                    const outerR  = r - tickW * 2
                    const innerR  = outerR - tickLen

                    const minuteLen = (outerR + innerR) / 2  // midpoint of perimeter
                    const hourLen   = minuteLen * 0.65

                    // Hour hand
                    face._drawHand(ctx, root._hourAngle,
                        hourLen,
                        r * 0.15,   // stemEnd
                        r * 0.0336, // stemW
                        r * 0.065,  // pillW
                        handColor
                    )

                    // Minute hand
                    face._drawHand(ctx, root._minuteAngle,
                        minuteLen,
                        r * 0.15,   // stemEnd
                        r * 0.0336, // stemW
                        r * 0.065,  // pillW
                        handColor
                    )

                    // Pivot circle covering stem bases
                    ctx.beginPath()
                    ctx.arc(0, 0, r * 0.050, 0, 2 * Math.PI)
                    ctx.fillStyle = handColor
                    ctx.fill()

                    ctx.restore()
                }

                Connections {
                    target: root
                    function on_hourAngleChanged()   { handsCanvas.requestPaint() }
                    function on_minuteAngleChanged() { handsCanvas.requestPaint() }
                }
                Connections {
                    target: colors
                    function onForegroundChanged() { handsCanvas.requestPaint() }
                }
                onWidthChanged:  requestPaint()
                onHeightChanged: requestPaint()
            }

            // --- Second hand ---
            Canvas {
                id: secondCanvas
                anchors.fill: parent
                z: 10
                renderStrategy: Canvas.Immediate

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx           = width / 2
                    const cy           = height / 2
                    const r            = Math.min(width, height) / 2
                    const tickW   = r * 0.020
                    const len     = r - tickW * 2  // reaches outward point of perimeter
                    const counterWeight = r * 0.15  // tail past pivot
                    const hw           = r * 0.007 * 1.3  // 1.3x thicker second hand

                    ctx.save()
                    ctx.translate(cx, cy)
                    ctx.rotate(root._secondAngle * Math.PI / 180)

                    ctx.fillStyle = "#F6A029"
                    ctx.beginPath()
                    ctx.rect(-hw, -len, hw * 2, len + counterWeight)
                    ctx.fill()

                    ctx.restore()
                }

                Connections {
                    target: root
                    function on_secondAngleChanged() { secondCanvas.requestPaint() }
                }
                onWidthChanged:  requestPaint()
                onHeightChanged: requestPaint()
            }

            // --- Center hinge dot (topmost) ---
            Canvas {
                id: hingeCanvas
                anchors.fill: parent
                z: 20
                renderStrategy: Canvas.Immediate

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx = width / 2
                    const cy = height / 2
                    const r  = Math.min(width, height) / 2

                    ctx.save()
                    ctx.translate(cx, cy)

                    ctx.beginPath()
                    ctx.arc(0, 0, r * 0.035, 0, 2 * Math.PI)
                    ctx.fillStyle = "#F6A029"
                    ctx.fill()

                    ctx.restore()
                }

                onWidthChanged:  requestPaint()
                onHeightChanged: requestPaint()
            }
        }
    }
}
