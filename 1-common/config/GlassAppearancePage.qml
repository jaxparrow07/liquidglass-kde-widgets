// Shared, tabbed "Appearance" config page for every Liquid Glass widget.
//
// Canonical copy lives in 1-common/config/ and is symlinked into each
// package's contents/ui/config/ next to the ConfigAppearance.qml that uses
// it (QML resolves the type from that directory). SliderField.qml must be
// symlinked alongside it.
//
// Tabs:
//   Style              - the everyday settings (style, appearance, shape,
//                        tint) plus any widget-specific `styleExtras`
//   Glass              - refraction / dispersion / specular tuning
//   Blur & performance - blur algorithm + radius, realtime capture
//
// Every control stays instantiated (tabs only toggle visibility), so all
// `cfg_*` aliases keep working and Apply saves every tab at once.
//
// Variants (analog clocks, glass-text clock) use this as their root type:
//   GlassAppearancePage {
//       property alias cfg_myKey: myCheck.checked
//       styleExtras: [ CheckBox { id: myCheck; Kirigami.FormData.label: ... } ]
//       serializeExtras: (o) => { o.mk = myCheck.checked }
//       deserializeExtras: (o) => { if (o.mk !== undefined) myCheck.checked = o.mk }
//   }

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils

KCMUtils.SimpleKCM {
    id: root

    // ── Config bindings ───────────────────────────────────────────────────
    // Keys a widget doesn't define are simply never read or written by the
    // config dialog, so these are safe for every package.
    property alias cfg_styleMode: styleCombo.currentIndex
    property alias cfg_autoStyle: autoStyleCheck.checked
    property alias cfg_styleFadeMs: fadeField.value
    property alias cfg_appearance: appearanceCombo.currentIndex
    property alias cfg_cornerRadius: radiusField.value
    property alias cfg_roundnessX10: roundnessField.value
    property alias cfg_tintAlphaPct: tintField.value
    property alias cfg_refractThickness: thicknessField.value
    property alias cfg_refractIORx100: iorField.value
    property alias cfg_refractScale: scaleField.value
    property alias cfg_chromaStrengthPct: chromaField.value
    property alias cfg_specStrengthPct: specField.value
    property alias cfg_blurAlgorithm: blurAlgorithmCombo.currentIndex
    property alias cfg_blurRadiusPx: blurRadiusField.value
    property alias cfg_realtimeRefraction: realtimeCheck.checked

    // Per-widget defaults, injected by the config dialog. The fallbacks
    // match the most common main.xml values. Used by the Reset buttons.
    property int cfg_refractThicknessDefault: 35
    property int cfg_refractIORx100Default: 170
    property int cfg_refractScaleDefault: 65
    property int cfg_chromaStrengthPctDefault: 30
    property int cfg_specStrengthPctDefault: 70
    property int cfg_blurAlgorithmDefault: 0
    property int cfg_blurRadiusPxDefault: 6
    property bool cfg_realtimeRefractionDefault: false
    property bool cfg_autoStyleDefault: true

    // ── Variant hooks ─────────────────────────────────────────────────────
    // Widgets without these settings (e.g. the glass-text clock) hide them.
    property bool showShape: true
    property bool showTint: true
    // False for widgets that switch style without a StyleFade.
    property bool showFade: true
    // Whether the glass backdrop is in use; analog clocks also use it in
    // Solid style unless the background is fully opaque.
    property bool glassBackdropActive: styleCombo.currentIndex === 0 || autoStyleCheck.checked
    // Extra controls appended to the Style tab's form.
    property list<Item> styleExtras
    // Copy/paste style support for the extras.
    property var serializeExtras: (o) => {}
    property var deserializeExtras: (o) => {}

    Component.onCompleted: {
        for (let i = 0; i < styleExtras.length; i++)
            styleExtras[i].parent = styleForm
    }

    // ── Copy / paste style ────────────────────────────────────────────────
    function _serialize() {
        const o = {
            s: styleCombo.currentIndex,
            as: autoStyleCheck.checked,
            a: appearanceCombo.currentIndex,
            cr: radiusField.value,
            rn: roundnessField.value,
            ta: tintField.value,
            rt: thicknessField.value,
            ri: iorField.value,
            rs: scaleField.value,
            ca: chromaField.value,
            ss: specField.value,
            ba: blurAlgorithmCombo.currentIndex,
            br: blurRadiusField.value,
            rr: realtimeCheck.checked,
            fd: fadeField.value
        }
        serializeExtras(o)
        return JSON.stringify(o)
    }

    function _deserialize(text) {
        try {
            const o = JSON.parse(text)
            if (o.s  !== undefined) styleCombo.currentIndex = o.s
            if (o.as !== undefined) autoStyleCheck.checked = o.as
            if (o.a  !== undefined) appearanceCombo.currentIndex = o.a
            if (o.cr !== undefined) radiusField.value = o.cr
            if (o.rn !== undefined) roundnessField.value = o.rn
            if (o.ta !== undefined) tintField.value = o.ta
            if (o.rt !== undefined) thicknessField.value = o.rt
            if (o.ri !== undefined) iorField.value = o.ri
            if (o.rs !== undefined) scaleField.value = o.rs
            if (o.ca !== undefined) chromaField.value = o.ca
            if (o.ss !== undefined) specField.value = o.ss
            if (o.ba !== undefined) blurAlgorithmCombo.currentIndex = o.ba
            else if (o.blurAlgorithm !== undefined) blurAlgorithmCombo.currentIndex = o.blurAlgorithm
            if (o.br !== undefined) blurRadiusField.value = o.br
            if (o.rr !== undefined) realtimeCheck.checked = o.rr
            if (o.fd !== undefined) fadeField.value = o.fd
            deserializeExtras(o)
            _showStatus(i18n("Style applied. Press Apply to keep it."))
        } catch (e) {
            _showStatus(i18n("The clipboard doesn't contain a copied style."))
        }
    }

    function _showStatus(text) {
        pasteStatus.text = text
        pasteStatus.visible = true
        statusTimer.restart()
    }

    Timer {
        id: statusTimer
        interval: 4000
        onTriggered: pasteStatus.visible = false
    }

    QQC2.TextField {
        id: clipboardBridge
        visible: false
    }

    // ── Tabs ──────────────────────────────────────────────────────────────
    // Tabs run edge to edge, like other KDE tabbed settings pages.
    headerPaddingEnabled: false
    header: QQC2.TabBar {
        id: tabBar
        objectName: "configTabBar"
        QQC2.TabButton { text: i18n("Style") }
        QQC2.TabButton { text: i18n("Glass") }
        QQC2.TabButton { text: i18n("Blur & performance") }
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        // ── Style ─────────────────────────────────────────────────────────
        Kirigami.FormLayout {
            id: styleForm
            Layout.fillWidth: true
            visible: tabBar.currentIndex === 0
            twinFormLayouts: [shareForm, glassForm, blurForm]

            QQC2.ComboBox {
                id: styleCombo
                Kirigami.FormData.label: i18n("Style:")
                model: [i18n("Glass"), i18n("Solid")]
                enabled: !autoStyleCheck.checked
            }

            QQC2.CheckBox {
                id: autoStyleCheck
                text: i18n("Switch automatically")
            }

            QQC2.Label {
                Layout.fillWidth: true
                visible: autoStyleCheck.checked
                wrapMode: Text.WordWrap
                opacity: 0.7
                text: i18n("Solid when the desktop is focused, Glass when a window is focused.")
            }

            // Collapsed every time the dialog opens.
            QQC2.Button {
                id: advancedButton
                visible: root.showFade && autoStyleCheck.checked
                flat: true
                checkable: true
                icon.name: checked ? "arrow-down" : "arrow-right"
                text: i18n("Advanced")
            }

            SliderField {
                id: fadeField
                Kirigami.FormData.label: i18n("Automatic switch fade:")
                visible: advancedButton.visible && advancedButton.checked
                from: 0; to: 600; stepSize: 50
                format: (v) => v === 0 ? i18n("Off") : i18nc("milliseconds", "%1 ms", v)
            }

            QQC2.ComboBox {
                id: appearanceCombo
                Kirigami.FormData.label: i18n("Appearance:")
                model: [i18n("Dark"), i18n("Light"), i18n("Follow system")]
            }

            SliderField {
                id: tintField
                Kirigami.FormData.label: i18n("Glass tint:")
                visible: root.showTint && root.glassBackdropActive
                from: 0; to: 100
                format: (v) => i18nc("percentage", "%1%", v)
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Shape")
                visible: root.showShape
            }

            SliderField {
                id: radiusField
                Kirigami.FormData.label: i18n("Corner radius:")
                visible: root.showShape
                from: 0; to: 200
                format: (v) => i18nc("pixels", "%1 px", v)
            }

            SliderField {
                id: roundnessField
                Kirigami.FormData.label: i18n("Corner smoothness:")
                visible: root.showShape
                from: 20; to: 100
                format: (v) => (v / 10).toFixed(1)
            }

            // styleExtras are reparented here, after this point.
        }

        // Kept in its own form (twinned for label alignment) so widget
        // extras land above it.
        Kirigami.FormLayout {
            id: shareForm
            Layout.fillWidth: true
            visible: tabBar.currentIndex === 0
            twinFormLayouts: [styleForm, glassForm, blurForm]

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Share")
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Style preset:")
                spacing: Kirigami.Units.smallSpacing

                QQC2.Button {
                    icon.name: "edit-copy"
                    text: i18n("Copy style")
                    onClicked: {
                        clipboardBridge.text = root._serialize()
                        clipboardBridge.selectAll()
                        clipboardBridge.copy()
                        root._showStatus(i18n("Copied. Paste it into another Liquid Glass widget."))
                    }
                }

                QQC2.Button {
                    icon.name: "edit-paste"
                    text: i18n("Paste style")
                    onClicked: {
                        clipboardBridge.text = ""
                        clipboardBridge.paste()
                        root._deserialize(clipboardBridge.text)
                    }
                }
            }

            QQC2.Label {
                id: pasteStatus
                visible: false
                Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                wrapMode: Text.WordWrap
                font.italic: true
                opacity: 0.75
            }
        }

        // ── Glass ─────────────────────────────────────────────────────────
        ColumnLayout {
            visible: tabBar.currentIndex === 1
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: !root.glassBackdropActive
                type: Kirigami.MessageType.Information
                text: i18n("These settings only apply to the Glass style.")
            }

            Kirigami.FormLayout {
                id: glassForm
                Layout.fillWidth: true
                enabled: root.glassBackdropActive
                // Shared label column across tabs, so fields don't jump on switch.
                twinFormLayouts: [styleForm, shareForm, blurForm]

                SliderField {
                    id: thicknessField
                    Kirigami.FormData.label: i18n("Edge thickness:")
                    from: 1; to: 80
                    format: (v) => i18nc("pixels", "%1 px", v)
                }

                SliderField {
                    id: scaleField
                    Kirigami.FormData.label: i18n("Refraction strength:")
                    from: 0; to: 300; stepSize: 5
                    format: (v) => i18nc("percentage", "%1%", v)
                }

                SliderField {
                    id: iorField
                    Kirigami.FormData.label: i18n("Refraction index:")
                    from: 100; to: 400; stepSize: 5
                    format: (v) => (v / 100).toFixed(2)
                }

                SliderField {
                    id: chromaField
                    Kirigami.FormData.label: i18n("Color fringing:")
                    from: 0; to: 100
                    format: (v) => i18nc("percentage", "%1%", v)
                }

                SliderField {
                    id: specField
                    Kirigami.FormData.label: i18n("Edge highlight:")
                    from: 0; to: 100; stepSize: 5
                    format: (v) => i18nc("percentage", "%1%", v)
                }

                QQC2.Button {
                    icon.name: "edit-reset"
                    text: i18n("Reset glass settings")
                    onClicked: {
                        thicknessField.value = root.cfg_refractThicknessDefault
                        scaleField.value = root.cfg_refractScaleDefault
                        iorField.value = root.cfg_refractIORx100Default
                        chromaField.value = root.cfg_chromaStrengthPctDefault
                        specField.value = root.cfg_specStrengthPctDefault
                    }
                }
            }
        }

        // ── Blur & performance ───────────────────────────────────────────
        ColumnLayout {
            visible: tabBar.currentIndex === 2
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: !root.glassBackdropActive
                type: Kirigami.MessageType.Information
                text: i18n("These settings only apply to the Glass style.")
            }

            Kirigami.FormLayout {
                id: blurForm
                Layout.fillWidth: true
                enabled: root.glassBackdropActive
                twinFormLayouts: [styleForm, shareForm, glassForm]

                SliderField {
                    id: blurRadiusField
                    Kirigami.FormData.label: i18n("Blur radius:")
                    from: 0; to: 100
                    format: (v) => v === 0 ? i18n("Off") : i18nc("pixels", "%1 px", v)
                }

                QQC2.ComboBox {
                    id: blurAlgorithmCombo
                    Kirigami.FormData.label: i18n("Blur quality:")
                    model: [i18n("Performance (Dual Kawase)"), i18n("Quality (Gaussian)")]
                }

                QQC2.Label {
                    visible: blurAlgorithmCombo.currentIndex === 1
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                    wrapMode: Text.WordWrap
                    opacity: 0.75
                    text: i18n("Smoother blur, but uses more GPU.")
                }

                QQC2.CheckBox {
                    id: realtimeCheck
                    Kirigami.FormData.label: i18n("Animated wallpapers:")
                    text: i18n("Update the glass every frame")
                }

                QQC2.Label {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                    wrapMode: Text.WordWrap
                    opacity: 0.75
                    text: realtimeCheck.checked
                        ? i18n("Runs at about 60 FPS and can noticeably increase CPU/GPU usage. Only needed for video or animated wallpapers.")
                        : i18n("Only needed for video or animated wallpapers. Static wallpapers and slideshows update automatically.")
                }

                QQC2.Button {
                    icon.name: "edit-reset"
                    text: i18n("Reset blur settings")
                    onClicked: {
                        blurRadiusField.value = root.cfg_blurRadiusPxDefault
                        blurAlgorithmCombo.currentIndex = root.cfg_blurAlgorithmDefault
                        realtimeCheck.checked = root.cfg_realtimeRefractionDefault
                    }
                }
            }
        }
    }
}
