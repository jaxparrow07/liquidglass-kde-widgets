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

    // --- Time state ---
    // `now` is the minute-level clock used to drive digital display +
    // hour label. Bumped once per minute by minuteWatchdog. The
    // second-hand sweep does NOT read `now` — it reads Date.now()
    // directly every frame (avoids per-frame property churn).
    property date now: new Date()
    readonly property int hour12: ((now.getHours() + 11) % 12) + 1
    readonly property int minute: now.getMinutes()

    Timer {
        id: minuteWatchdog
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            const n = new Date();
            if (n.getMinutes() !== root.now.getMinutes() || n.getHours() !== root.now.getHours() || n.getDate() !== root.now.getDate()) {
                root.now = n;
            }
        }
    }

    fullRepresentation: Item {
        id: full
        Layout.preferredWidth: 200
        Layout.preferredHeight: 200
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
    }
}
