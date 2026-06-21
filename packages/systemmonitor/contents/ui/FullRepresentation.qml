import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import QtQml

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

import org.kde.ksysguard.faces as Faces

import "components"


Control {
    id: chartFace

    Layout.minimumWidth: (contentItem ? contentItem.Layout.minimumWidth : 0) + leftPadding + rightPadding
    Layout.minimumHeight: (contentItem ? contentItem.Layout.minimumHeight : 0) + topPadding + bottomPadding
    Layout.preferredWidth: (contentItem
            ? (contentItem.Layout.preferredWidth > 0 ? contentItem.Layout.preferredWidth : contentItem.implicitWidth)
            : 0) + leftPadding + rightPadding
    Layout.preferredHeight: (contentItem
            ? (contentItem.Layout.preferredHeight > 0 ? contentItem.Layout.preferredHeight : contentItem.implicitHeight)
            : 0) + topPadding + bottomPadding
    Layout.maximumWidth: (contentItem ? contentItem.Layout.maximumWidth : 0) + leftPadding + rightPadding
    Layout.maximumHeight: (contentItem ? contentItem.Layout.maximumHeight : 0) + topPadding + bottomPadding

    padding: Math.round(Kirigami.Units.gridUnit * 0.75)

    MacOSColors {
        id: colors
        styleMode: plasmoid.configuration.styleMode
        appearance: plasmoid.configuration.appearance
    }

    background: LiquidGlass {
        id: glass
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

    contentItem: Plasmoid.faceController.fullRepresentation

    Binding {
        target: Plasmoid.faceController.fullRepresentation
        property: "formFactor"
        value: {
            switch (Plasmoid.formFactor) {
            case PlasmaCore.Types.Horizontal:
                return Faces.SensorFace.Horizontal;
            case PlasmaCore.Types.Vertical:
                return Faces.SensorFace.Vertical;
            default:
                return Faces.SensorFace.Planar;
            }
        }
        restoreMode: Binding.RestoreBinding
    }
}
