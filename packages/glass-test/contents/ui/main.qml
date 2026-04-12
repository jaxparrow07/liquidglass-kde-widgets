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
        themeMode: plasmoid.configuration.themeMode
    }

    fullRepresentation: Item {
        Layout.preferredWidth: 320
        Layout.preferredHeight: 200
        Layout.minimumWidth: 160
        Layout.minimumHeight: 100

        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: plasmoid.configuration.cornerRadius
            roundness: plasmoid.configuration.roundness
            refractThickness: plasmoid.configuration.refractThickness
            refractIOR: plasmoid.configuration.refractIORx100 / 100
            refractScale: plasmoid.configuration.refractScale
            tint: colors.glassTint
            tintAlpha: plasmoid.configuration.tintAlphaPct / 100
            chromaStrength: plasmoid.configuration.chromaStrengthPct / 100
            fallbackOpacity: colors.glassFallbackOpacity
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Liquid Glass"
                color: colors.labelPrimary
                font.pixelSize: 28
                font.weight: Font.DemiBold
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: glass.active ? "wallpaper sampled" : "fallback (no wallpaper)"
                color: colors.labelSecondary
                font.pixelSize: 11
            }
        }
    }
}
