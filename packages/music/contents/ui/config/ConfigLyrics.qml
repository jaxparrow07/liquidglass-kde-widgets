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
    property alias cfg_lyricsActiveScale: activeScaleSpin.value

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

        SpinBox {
            id: activeScaleSpin
            Kirigami.FormData.label: i18n("Active line scale (%):")
            from: 100; to: 130; stepSize: 5
        }
    }
}
