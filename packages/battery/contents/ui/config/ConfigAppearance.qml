import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root
    spacing: Kirigami.Units.largeSpacing

    property alias cfg_styleMode: styleCombo.currentIndex
    property alias cfg_appearance: appearanceCombo.currentIndex
    property alias cfg_cornerRadius: radiusSpin.value
    property alias cfg_roundnessX10: roundnessSpin.value
    property alias cfg_refractThickness: thicknessSpin.value
    property alias cfg_refractIORx100: iorSpin.value
    property alias cfg_refractScale: scaleSpin.value
    property alias cfg_tintAlphaPct: tintSpin.value
    property alias cfg_chromaStrengthPct: chromaSpin.value
    property alias cfg_specStrengthPct: specStrengthSpin.value
    property alias cfg_blurRadiusPx: blurRadiusSpin.value
    property alias cfg_realtimeRefraction: realtimeCheck.checked

    function _serialize() {
        return JSON.stringify({
            s: styleCombo.currentIndex,
            a: appearanceCombo.currentIndex,
            cr: radiusSpin.value,
            rn: roundnessSpin.value,
            rt: thicknessSpin.value,
            ri: iorSpin.value,
            rs: scaleSpin.value,
            ta: tintSpin.value,
            ca: chromaSpin.value,
            ss: specStrengthSpin.value,
            br: blurRadiusSpin.value,
            rr: realtimeCheck.checked
        })
    }

    function _deserialize(text) {
        try {
            var o = JSON.parse(text)
            if (o.s  !== undefined) styleCombo.currentIndex      = o.s
            if (o.a  !== undefined) appearanceCombo.currentIndex  = o.a
            if (o.cr !== undefined) radiusSpin.value              = o.cr
            if (o.rn !== undefined) roundnessSpin.value           = o.rn
            if (o.rt !== undefined) thicknessSpin.value           = o.rt
            if (o.ri !== undefined) iorSpin.value                 = o.ri
            if (o.rs !== undefined) scaleSpin.value               = o.rs
            if (o.ta !== undefined) tintSpin.value                = o.ta
            if (o.ca !== undefined) chromaSpin.value              = o.ca
            if (o.ss !== undefined) specStrengthSpin.value        = o.ss
            if (o.br !== undefined) blurRadiusSpin.value          = o.br
            if (o.rr !== undefined) realtimeCheck.checked         = o.rr
            pasteStatus.text = i18n("Applied!")
        } catch(e) {
            pasteStatus.text = i18n("Invalid config string")
        }
        pasteStatus.visible = true
        statusTimer.restart()
    }

    Timer {
        id: statusTimer
        interval: 3000
        onTriggered: pasteStatus.visible = false
    }

    Kirigami.FormLayout {
        Layout.fillWidth: true

        RowLayout {
            Kirigami.FormData.label: i18n("Preset:")
            spacing: Kirigami.Units.smallSpacing

            Button {
                icon.name: "edit-copy"
                text: i18n("Copy style")
                onClicked: {
                    _hiddenField.text = root._serialize()
                    _hiddenField.selectAll()
                    _hiddenField.copy()
                    pasteStatus.text = i18n("Copied!")
                    pasteStatus.visible = true
                    statusTimer.restart()
                }
            }

            Button {
                icon.name: "edit-paste"
                text: i18n("Paste style")
                onClicked: {
                    _hiddenField.text = ""
                    _hiddenField.paste()
                    root._deserialize(_hiddenField.text)
                }
            }
        }

        TextField {
            id: _hiddenField
            visible: false
        }

        Label {
            id: pasteStatus
            visible: false
            font.italic: true
            opacity: 0.7
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
        }

        ComboBox {
            id: styleCombo
            Kirigami.FormData.label: i18n("Style:")
            model: [i18n("Glass"), i18n("Solid")]
        }

        ComboBox {
            id: appearanceCombo
            Kirigami.FormData.label: i18n("Appearance:")
            model: [i18n("Dark"), i18n("Light"), i18n("Follow system")]
        }

        SpinBox {
            id: radiusSpin
            Kirigami.FormData.label: i18n("Corner radius (px):")
            from: 0; to: 200; stepSize: 1
        }

        SpinBox {
            id: roundnessSpin
            Kirigami.FormData.label: i18n("Roundness (×10, 2.0..10.0):")
            from: 20; to: 100; stepSize: 1
        }
    }

    Kirigami.FormLayout {
        id: glassSection
        Layout.fillWidth: true
        visible: styleCombo.currentIndex === 0

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Glass effect")
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

        SpinBox {
            id: specStrengthSpin
            Kirigami.FormData.label: i18n("Specular strength (%):")
            from: 0; to: 100; stepSize: 5
        }

        SpinBox {
            id: blurRadiusSpin
            Kirigami.FormData.label: i18n("Blur radius (px):")
            from: 0; to: 100; stepSize: 1
        }

        CheckBox {
            id: realtimeCheck
            Kirigami.FormData.label: i18n("Realtime refraction:")
            text: i18n("Recapture every frame (enable for video wallpapers)")
        }
    }
}
