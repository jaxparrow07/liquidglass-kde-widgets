// Analog-clock variant of the shared appearance page.
//
// Adds `opaqueBackground`: in Solid mode the analog clocks render their
// background squircle with the glass material by default (solid clock face
// on a glass card). Checking "Fully opaque background" reverts to the flat
// opaque fill. Because the glass material then also backs Solid mode, the
// glass settings stay enabled whenever the backdrop is actually in use.

import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

GlassAppearancePage {
    id: page

    property alias cfg_opaqueBackground: opaqueCheck.checked

    glassBackdropActive: cfg_styleMode === 0 || cfg_autoStyle || !opaqueCheck.checked

    styleExtras: [
        QQC2.CheckBox {
            id: opaqueCheck
            Kirigami.FormData.label: i18n("Background:")
            text: i18n("Fully opaque background")
            visible: page.cfg_styleMode === 1 || page.cfg_autoStyle
        }
    ]

    serializeExtras: (o) => { o.ob = opaqueCheck.checked }
    deserializeExtras: (o) => { if (o.ob !== undefined) opaqueCheck.checked = o.ob }
}
