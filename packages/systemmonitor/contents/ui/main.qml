import QtQuick
import QtQuick.Layouts
import QtQuick.Window

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

import org.kde.ksysguard.sensors as Sensors

import "components"


PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    MacOSColors {
        id: colors
        styleMode: plasmoid.configuration.styleMode
        appearance: plasmoid.configuration.appearance
    }

    function switchSizeFromSize(formFactor, compactMax, fullMin) {
        if (Plasmoid.formFactor === PlasmaCore.Types.Planar) {
            return -1
        }

        if (Plasmoid.formFactor === formFactor) {
            return 1
        }

        if (!Number.isFinite(compactMax)) {
            compactMax = Kirigami.Units.iconSizes.enormous - 1
        }

        if (fullMin <= 0) {
            fullMin = Kirigami.Units.iconSizes.enormous - 1
        }

        return Math.max(compactMax, fullMin)
    }

    switchWidth: switchSizeFromSize(PlasmaCore.Types.Horizontal, compactRepresentationItem?.Layout.maximumWidth ?? Infinity, fullRepresentationItem?.Layout.minimumWidth ?? -1)
    switchHeight: switchSizeFromSize(PlasmaCore.Types.Vertical, compactRepresentationItem?.Layout.maximumHeight ?? Infinity, fullRepresentationItem?.Layout.minimumHeight ?? -1)

    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : null

    Plasmoid.title: Plasmoid.faceController?.title || i18n("System Monitor")
    toolTipSubText: totalSensor.sensorId ? i18nc("Sensor name: value", "%1: %2", totalSensor.name, totalSensor.formattedValue) : ""

    compactRepresentation: CompactRepresentation {
    }
    fullRepresentation: FullRepresentation {
    }

    Plasmoid.configurationRequired: (Plasmoid.faceController ?? false) &&
        Plasmoid.faceController.highPrioritySensorIds.length == 0 &&
        Plasmoid.faceController.lowPrioritySensorIds.length == 0 &&
        Plasmoid.faceController.totalSensors.length == 0 &&
        ! (["org.kde.ksysguard.applicationstable",
            "org.kde.ksysguard.processtable"].includes(Plasmoid.faceController.faceId))

    Sensors.Sensor {
        id: totalSensor
        sensorId: Plasmoid.faceController?.totalSensors[0] || ""
        updateRateLimit: Plasmoid.faceController?.updateRateLimit
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        onClicked: Plasmoid.openSystemMonitor()
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18nc("@action", "Open System Monitor…")
            icon.name: "utilities-system-monitor"
            onTriggered: Plasmoid.openSystemMonitor()
        }
    ]
}
