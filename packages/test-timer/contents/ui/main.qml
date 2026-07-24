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
        id: sfThin
        source: Qt.resolvedUrl("../fonts/sf_pro_display_thin.otf")
    }

    property int secondsDigit: new Date().getSeconds() % 10

    Timer {
        interval: 1000 - (new Date().getMilliseconds())
        repeat: true
        running: true
        triggeredOnStart: false
        onTriggered: {
            root.secondsDigit = new Date().getSeconds() % 10
            interval = 1000 - (new Date().getMilliseconds())
        }
    }

    fullRepresentation: Item {
        id: full
        Layout.preferredWidth:  full.width  > 0 ? full.width  : 200
        Layout.preferredHeight: full.height > 0 ? full.height : 200
        Layout.minimumWidth: 120
        Layout.minimumHeight: 120

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

        Item {
            id: digitViewport
            anchors.centerIn: parent
            width: Math.min(full.width, full.height) * 0.64
            height: Math.min(full.width, full.height) * 0.94
            clip: true

            RollingDigit {
                anchors.fill: parent
                value: String(root.secondsDigit)
                fontFamily: sfThin.name
                fontPixelSize: Math.min(full.width, full.height) * 0.62
                textColor: colors.foreground
                digitOpacity: colors.isGlass ? 0.62 : 0.92
            }
        }
    }
}
