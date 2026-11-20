import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Photos")
        icon: "folder-pictures"
        source: "config/ConfigPhotos.qml"
    }
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-theme"
        source: "config/ConfigAppearance.qml"
    }
    ConfigCategory {
        name: i18n("More & Support")
        icon: Qt.resolvedUrl("../ui/icons/about/bmc-icon.svg")
        source: "config/ConfigAbout.qml"
    }
}
