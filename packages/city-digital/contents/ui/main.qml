import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
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
    }

    FontLoader {
        id: barlowSemiBold
        source: Qt.resolvedUrl("../fonts/barlow_semibold.ttf")
    }
    FontLoader {
        id: barlowMedium
        source: Qt.resolvedUrl("../fonts/barlow_medium.ttf")
    }
    FontLoader {
        id: sfProRounded
        source: Qt.resolvedUrl("../fonts/sf_pro_rounded.otf")
    }

    // --- Time state ---
    // City Digital shows a single configured city (1x1 only). The digital
    // readout reads hour12/minute from the world-clock model (updated once a
    // second); the second-hand sweep below reads Date.now() directly.
    WorldClock {
        id: world
        clocks: plasmoid.configuration.clocks
        needsSeconds: false
    }
    readonly property var _e: world.entries.length ? world.entries[0] : null
    readonly property int hour12: _e ? _e.hour12 : ((new Date().getHours() + 11) % 12) + 1
    readonly property int minute: _e ? _e.minute : new Date().getMinutes()

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
            solidMode: colors.isSolid
            solidColor: colors.solidBackground
        }

        TickRing {
            id: ticks
            anchors.fill: parent
            cornerRadius: glass.radius
            roundness: glass.roundness
            outerInset: 0.05
            tickLength: 0.026
            cornerOuterExtension: 0.012
            tickWidthPx: 2.2
            baseOpacity: colors.isGlass ? 0.18 : 0.30
            tickColor: colors.foreground
        }

        // Smoothly advance the second hand at ~60fps while visible.
        // Don't gate on application state — Plasma desktop widgets must
        // keep ticking even when no Qt window has keyboard focus.
        Timer {
            interval: 16
            repeat: true
            running: full.visible
            onTriggered: {
                const ms = Date.now() % 60000;
                ticks.secondHandAngle = (ms / 60000) * 360;
            }
        }

        DigitalTime {
            anchors.centerIn: parent
            fontFamily: barlowMedium.name
            // Generous target size; the component auto-shrinks if the
            // content would overflow `availableWidth`.
            fontPixelSize: Math.min(full.width, full.height) * 0.60
            // Usable interior: widget width minus the same visual gap
            // on both sides that the ticks leave to the edge (5% inset
            // + 5% tick length + 5% pad = 15% each side).
            availableWidth: Math.max(40, full.width - 2 * Math.min(full.width, full.height) * 0.15)
            hour12: root.hour12
            minute: root.minute
            digitOpacity: colors.isGlass ? 0.55 : 1.0
            textColor: colors.foreground
        }

        // City code near the top edge, hour-diff near the bottom edge, with
        // equal margins so the two gaps are even. Smaller than the clock text,
        // and 15% lower opacity than the clock's digitOpacity (in both modes).
        readonly property real _annoFont:   Math.max(8, Math.min(full.width, full.height) * 0.085)
        readonly property real _annoMargin: Math.min(full.width, full.height) * 0.13
        readonly property real _annoOpacity: (colors.isGlass ? 0.55 : 1.0) * 0.55

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: full._annoMargin
            text: root._e ? root._e.code : ""
            font.family: sfProRounded.name
            font.pixelSize: full._annoFont
            font.weight: Font.Medium
            color: colors.foreground
            opacity: full._annoOpacity
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: full._annoMargin
            text: root._e ? root._e.offsetLabel : ""
            font.family: sfProRounded.name
            font.pixelSize: full._annoFont
            font.weight: Font.Medium
            color: colors.foreground
            opacity: full._annoOpacity
        }
    }
}
