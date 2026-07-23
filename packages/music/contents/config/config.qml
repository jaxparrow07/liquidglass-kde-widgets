import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-theme"
        source: "config/ConfigAppearance.qml"
    }
    ConfigCategory {
        name: i18n("Lyrics")
        icon: "preferences-desktop-font"
        source: "config/ConfigLyrics.qml"
    }
    ConfigCategory {
        name: i18n("More & Support")
        icon: "love"
        source: "config/ConfigAbout.qml"
    }
}
