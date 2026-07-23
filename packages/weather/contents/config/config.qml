import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-theme"
        source: "config/ConfigAppearance.qml"
    }
    ConfigCategory {
        name: i18n("Weather")
        icon: "weather-clear"
        source: "config/ConfigGeneral.qml"
    }
    ConfigCategory {
        name: i18n("More & Support")
        icon: "love"
        source: "config/ConfigAbout.qml"
    }
}
