import QtQuick
import org.kde.plasma.private.battery as Battery

Battery.BatteryControlModel {
    id: battery

    property int percentage: percent
    property bool isCharging: state === Battery.BatteryControlModel.Charging
    property bool isPresent: hasBatteries

    readonly property string statusText: {
        if (!isPresent) return "No Battery"
        if (state === Battery.BatteryControlModel.Charging) return "Charging"
        if (state === Battery.BatteryControlModel.FullyCharged) return "Fully Charged"
        if (percentage <= 10) return "Low Battery"
        return "On Battery"
    }

    readonly property color batteryColor: {
        if (isCharging) return "#34C759"
        if (percentage <= 10) return "#FF3B30"
        if (percentage <= 25) return "#FF9500"
        return "#34C759"
    }
}
