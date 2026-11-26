// Glass-text clock variant of the shared appearance page
// (GlassAppearancePage.qml, symlinked from 1-common/config).
//
// The glyphs are the glass, so there is no corner shape or glass tint;
// instead this adds the digit font and the text overlay settings.

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

GlassAppearancePage {
    id: page

    property alias cfg_glyphFont: fontCombo.currentIndex
    property alias cfg_textTintPct: textTintField.value
    // textColor is a String kcfg; bridge it through a string property the
    // ColorButton reads/writes as a #rrggbb hex.
    property string cfg_textColor: "#ffffff"

    showShape: false
    showTint: false
    showFade: false

    styleExtras: [
        QQC2.ComboBox {
            id: fontCombo
            Kirigami.FormData.label: i18n("Digit font:")
            // Order MUST match _glyphFonts in main.qml.
            model: [i18n("SF Pro Soft"), i18n("SF Pro Rounded"),
                    i18n("SF Pro Rails"), i18n("New York"), i18n("SF Pro Stencil")]
        },
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Text overlay")
        },
        SliderField {
            id: textTintField
            Kirigami.FormData.label: i18n("Text tint:")
            // 0 = fully transparent (refraction-only glass), 100 = solid text.
            from: 0; to: 100
            format: (v) => v === 0 ? i18n("Off") : i18nc("percentage", "%1%", v)
        },
        KQuickControls.ColorButton {
            id: textColorButton
            Kirigami.FormData.label: i18n("Text color:")
            enabled: textTintField.value > 0
            // Seed from the stored config once, then act as the source of truth.
            Component.onCompleted: color = page.cfg_textColor
            onColorChanged: page.cfg_textColor = color.toString()
        }
    ]

    serializeExtras: (o) => {
        o.gf = fontCombo.currentIndex
        o.tt = textTintField.value
        o.tc = page.cfg_textColor
    }
    deserializeExtras: (o) => {
        if (o.gf !== undefined) fontCombo.currentIndex = o.gf
        if (o.tt !== undefined) textTintField.value = o.tt
        if (o.tc !== undefined) textColorButton.color = o.tc
    }
}
