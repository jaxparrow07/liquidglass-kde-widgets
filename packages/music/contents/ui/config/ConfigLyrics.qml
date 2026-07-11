import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root
    spacing: Kirigami.Units.largeSpacing

    property alias cfg_lyricsActiveOpacity: activeOpacitySpin.value
    property alias cfg_lyricsInactiveOpacity: inactiveOpacitySpin.value
    property alias cfg_lyricsFontSizeWide: wideFontSpin.value
    property alias cfg_lyricsFontSizeTall: tallFontSpin.value
    property alias cfg_lyricsBlur: lyricsBlurCheck.checked
    property alias cfg_artRefreshEnabled: artRefreshCheck.checked

    Kirigami.FormLayout {
        Layout.fillWidth: true

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Opacity")
        }

        SpinBox {
            id: activeOpacitySpin
            Kirigami.FormData.label: i18n("Active line (%):")
            from: 50; to: 100; stepSize: 5
        }

        SpinBox {
            id: inactiveOpacitySpin
            Kirigami.FormData.label: i18n("Inactive lines (%):")
            from: 5; to: 80; stepSize: 5
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Size")
        }

        SpinBox {
            id: wideFontSpin
            Kirigami.FormData.label: i18n("Wide layout font (‰):")
            from: 40; to: 150; stepSize: 5
        }

        SpinBox {
            id: tallFontSpin
            Kirigami.FormData.label: i18n("Tall layout font (‰):")
            from: 30; to: 120; stepSize: 5
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Effects")
        }

        CheckBox {
            id: lyricsBlurCheck
            Kirigami.FormData.label: i18n("Blur upcoming lines:")
            text: i18n("Blur upcoming lyrics lines (disable on slow hardware)")
        }

        CheckBox {
            id: artRefreshCheck
            Kirigami.FormData.label: i18n("Pause on track change:")
            text: i18n("Briefly pause/resume to refresh album art (causes playback hiccups)")
        }

    }
}
