import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    property alias cfg_themeMode: themeCombo.currentIndex
    property alias cfg_cornerRadius: radiusSpin.value
    property alias cfg_roundness: roundnessSpin.value
    property alias cfg_refractThickness: thicknessSpin.value
    property alias cfg_refractIORx100: iorSpin.value
    property alias cfg_refractScale: scaleSpin.value
    property alias cfg_tintAlphaPct: tintSpin.value
    property alias cfg_chromaStrengthPct: chromaSpin.value

    ComboBox {
        id: themeCombo
        Kirigami.FormData.label: i18n("Theme:")
        model: [i18n("Dark"), i18n("Light"), i18n("Follow system")]
    }

    SpinBox {
        id: radiusSpin
        Kirigami.FormData.label: i18n("Corner radius (px):")
        from: 0; to: 80; stepSize: 1
    }

    SpinBox {
        id: roundnessSpin
        Kirigami.FormData.label: i18n("Squircle roundness (2..7):")
        from: 2; to: 7; stepSize: 1
    }

    SpinBox {
        id: thicknessSpin
        Kirigami.FormData.label: i18n("Refraction thickness (px):")
        from: 1; to: 80; stepSize: 1
    }

    SpinBox {
        id: iorSpin
        Kirigami.FormData.label: i18n("Index of refraction (×100):")
        from: 100; to: 400; stepSize: 5
    }

    SpinBox {
        id: scaleSpin
        Kirigami.FormData.label: i18n("Refraction strength:")
        from: 0; to: 300; stepSize: 5
    }

    SpinBox {
        id: tintSpin
        Kirigami.FormData.label: i18n("Tint alpha (%):")
        from: 0; to: 100; stepSize: 1
    }

    SpinBox {
        id: chromaSpin
        Kirigami.FormData.label: i18n("Chromatic aberration (%):")
        from: 0; to: 100; stepSize: 1
    }
}
