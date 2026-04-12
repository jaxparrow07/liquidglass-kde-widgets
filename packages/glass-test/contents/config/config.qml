import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "preferences-desktop-theme"
        source: "config/ConfigGeneral.qml"
    }
}
