import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "components"
import "widget"

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    MacOSColors {
        id: colors
        styleMode: plasmoid.configuration.styleMode
        appearance: plasmoid.configuration.appearance
    }

    // Selectable glyph fonts for the HH:MM digits. Order MUST match the
    // ComboBox model in ConfigAppearance.qml and the glyphFont config index.
    FontLoader { id: fontSoft;    source: Qt.resolvedUrl("../fonts/ios_default_sbold_soft.otf") }
    FontLoader { id: fontRounded; source: Qt.resolvedUrl("../fonts/ios_rounded.otf") }
    FontLoader { id: fontRails;   source: Qt.resolvedUrl("../fonts/ios_rails.otf") }
    FontLoader { id: fontNewYork; source: Qt.resolvedUrl("../fonts/ios_newyork.otf") }
    FontLoader { id: fontStencil; source: Qt.resolvedUrl("../fonts/ios_stencil.otf") }

    readonly property var _glyphFonts: [fontSoft.name, fontRounded.name,
                                        fontRails.name, fontNewYork.name, fontStencil.name]
    readonly property string glyphFontName: {
        var i = plasmoid.configuration.glyphFont
        return (i >= 0 && i < _glyphFonts.length) ? _glyphFonts[i] : fontSoft.name
    }
    // The day/date label always uses the soft font, independent of the picker.
    readonly property string dayFontName: fontSoft.name

    // --- Time state (minute resolution; bumped once per minute) ---
    property date now: new Date()
    readonly property int hour12: ((now.getHours() + 11) % 12) + 1
    readonly property int minute: now.getMinutes()
    // "Date Day", e.g. "17 Wednesday" (no comma — the soft font's comma glyph
    // renders like a raised apostrophe, so a plain space separates them).
    readonly property string dayName: Qt.formatDate(now, "d  dddd")

    Timer {
        id: minuteWatchdog
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            const n = new Date();
            if (n.getMinutes() !== root.now.getMinutes()
                || n.getHours() !== root.now.getHours()
                || n.getDate() !== root.now.getDate()) {
                root.now = n;
            }
        }
    }

    fullRepresentation: Item {
        id: full
        Layout.preferredWidth: 300
        Layout.preferredHeight: 180
        Layout.minimumWidth: 180
        Layout.minimumHeight: 110

        // Shared typographic metrics for both the mask and the overlay.
        readonly property real _bigFont: Math.min(full.width * 0.42, full.height * 0.62)
        readonly property real _avail: Math.max(40, full.width * 0.86)

        // 1. Off-screen MASK: white glyphs on transparent. Not drawn directly;
        //    captured by TextGlass as the glass silhouette. Centered exactly
        //    like the overlay below.
        GlassClockText {
            id: glyphMask
            visible: false
            anchors.centerIn: parent
            width: full.width
            height: full.height
            fontFamily: root.glyphFontName
            dayFontFamily: root.dayFontName
            fontPixelSize: full._bigFont
            availableWidth: full._avail
            hour12: root.hour12
            minute: root.minute
            dayText: root.dayName
            glyphColor: "#ffffff"
            glyphOpacity: 1.0
        }

        // 2. The liquid glass, shaped by the mask's alpha. The SDF chain is
        //    fully live, so the digits' glass shape updates automatically.
        TextGlass {
            id: glass
            anchors.fill: parent
            maskSource: glyphMask
            refractThickness: plasmoid.configuration.refractThickness
            refractIOR: plasmoid.configuration.refractIORx100 / 100
            refractScale: plasmoid.configuration.refractScale
            // Glass material is pure refraction; appearance/tint is driven by
            // the optional text overlay (textTint/textColor), not a glass tint.
            tint: colors.glassTint
            tintAlpha: 0
            chromaStrength: plasmoid.configuration.chromaStrengthPct / 100
            specStrength: plasmoid.configuration.specStrengthPct / 100
            blurRadius: plasmoid.configuration.blurRadiusPx
            realtimeRefraction: plasmoid.configuration.realtimeRefraction
            fallbackOpacity: colors.glassFallbackOpacity
            solidMode: colors.isSolid
            solidColor: colors.solidBackground
        }

        // 3. Optional tinted text on top, aligned to the glass glyphs.
        //    textTintPct: 0 = fully transparent (refraction-only glass), 100 =
        //    solid colored text. Color from the config picker. Hidden entirely
        //    at 0% so the glass digits read as pure refraction.
        GlassClockText {
            id: overlay
            visible: colors.isGlass && plasmoid.configuration.textTintPct > 0
            anchors.centerIn: parent
            width: full.width
            height: full.height
            fontFamily: root.glyphFontName
            dayFontFamily: root.dayFontName
            fontPixelSize: full._bigFont
            availableWidth: full._avail
            hour12: root.hour12
            minute: root.minute
            dayText: root.dayName
            glyphColor: plasmoid.configuration.textColor
            glyphOpacity: plasmoid.configuration.textTintPct / 100
        }
    }
}
