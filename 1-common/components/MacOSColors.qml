import QtQuick
import org.kde.kirigami as Kirigami

QtObject {
    id: macColors

    // Two orthogonal axes:
    //   styleMode:  0 = Glass (translucent shader),  1 = Solid (opaque fill)
    //   appearance: 0 = Dark, 1 = Light, 2 = Follow system
    property int styleMode: 0
    property int appearance: 0

    readonly property bool useSystem: appearance === 2
    readonly property bool systemIsDark: {
        var bg = Kirigami.Theme.backgroundColor
        var luminance = 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
        return luminance < 0.5
    }
    readonly property bool isLight: !isGlass && (appearance === 1 || (useSystem && !systemIsDark))
    readonly property bool isGlass: styleMode === 0
    readonly property bool isSolid: styleMode === 1

    readonly property color background: isLight ? "#f2f2f7" : "#1c1c1e"
    readonly property color surface:    isLight ? "#ffffff" : "#2c2c2e"
    readonly property color surfaceAlt: isLight ? "#e5e5ea" : "#3a3a3c"

    readonly property color labelPrimary:    isLight ? "#000000" : "#ffffff"
    readonly property color labelSecondary:  isLight ? "#3c3c43" : "#ebebf5"
    readonly property color labelTertiary:   isLight ? "#3c3c4399" : "#ebebf599"
    readonly property color labelQuaternary: isLight ? "#3c3c432e" : "#ebebf52e"

    readonly property color accent: "#0a84ff"

    readonly property color separator: isLight ? "#3c3c4336" : "#54545899"

    // Glass mode tint — translucent overlay sampled by the shader.
    readonly property color glassTint: isLight ? "#ffffff" : "#000000"
    readonly property real  glassTintAlpha: isLight ? 0.60 : 0.32
    readonly property real  glassFallbackOpacity: isLight ? 0.72 : 0.55

    // Solid mode palette — opaque fill plus contrasting foreground.
    readonly property color solidBackground: isLight ? "#ffffff" : "#1A1B1E"
    readonly property color solidForeground: isLight ? "#1A1B1E" : "#ffffff"

    // Tuned reds for the today badge in Solid mode (Glass keeps it white).
    readonly property color accentRed: isLight ? "#D70015" : "#FF3B30"

    // Per-widget override: set to true/false to force foreground polarity
    // independent of appearance. Null means use the normal isLight logic.
    property var foregroundDarkOverride: null

    readonly property bool effectiveLight: foregroundDarkOverride !== null
        ? !foregroundDarkOverride
        : isLight

    // Foreground used by widget content. Glass stays monochromatic white
    // so the translucent shader keeps its existing look regardless of
    // appearance; Solid follows light/dark inversion.
    readonly property color foreground: isGlass ? "#ffffff" : (effectiveLight ? "#1A1B1E" : "#ffffff")

    // Today/highlight accent: white in Glass (monochrome) and red in Solid.
    readonly property color todayAccent: isGlass ? "#ffffff" : accentRed

    // Badge punch-out: glass uses destination-out compositing, solid uses normal text.
    readonly property bool punchOutText: isGlass

    // Card backgrounds — white on dark modes, black on light solid mode.
    readonly property color cardBackground:        isLight ? "#000000" : "#ffffff"
    readonly property real  cardBackgroundOpacity: isLight ? 0.08 : 0.10
    readonly property real  cardHoverOpacity:      isLight ? 0.14 : 0.17
    readonly property real  cardPressOpacity:      isLight ? 0.20 : 0.22

    // Timer action colors — solid-filled in glass, tinted in solid.
    readonly property color countdownText:  isGlass ? "#ffffff" : "#FF8B00"
    readonly property color actionGreen:    "#00A832"
    readonly property color actionOrange:   "#FF8E00"
    readonly property color buttonIcon:     isGlass ? "#ffffff" : solidForeground
    readonly property color cancelButtonBg: isGlass
        ? Qt.rgba(1, 1, 1, 0.25)
        : Qt.rgba(solidForeground.r, solidForeground.g, solidForeground.b, 0.12)
    readonly property color actionGreenBg:  isGlass ? "#00A832" : Qt.rgba(0, 0.659, 0.196, 0.18)
    readonly property color actionOrangeBg: isGlass ? "#FF8E00" : Qt.rgba(1, 0.557, 0, 0.18)

    // ── Weather tokens ────────────────────────────────────────────────
    property string weatherGradientCategory: "clear"

    readonly property color weatherGradientTop: {
        if (isGlass) return "transparent"
        var cat = weatherGradientCategory
        if (cat === "clear")       return "#5188BD"
        if (cat === "cloudy")      return "#8E9EAF"
        if (cat === "rain")        return "#607B8A"
        if (cat === "storm")       return "#3A3A4A"
        if (cat === "snow")        return "#B0C4DE"
        if (cat === "fog")         return "#9CA3AF"
        if (cat === "nightclear")  return "#1A1A3E"
        if (cat === "nightcloudy") return "#2C3040"
        return "#5188BD"
    }

    readonly property color weatherGradientBottom: {
        if (isGlass) return "transparent"
        var cat = weatherGradientCategory
        if (cat === "clear")       return "#194E84"
        if (cat === "cloudy")      return "#4A5568"
        if (cat === "rain")        return "#2C3E50"
        if (cat === "storm")       return "#1A1A2E"
        if (cat === "snow")        return "#708090"
        if (cat === "fog")         return "#6B7280"
        if (cat === "nightclear")  return "#0D0D2B"
        if (cat === "nightcloudy") return "#1A1E2A"
        return "#194E84"
    }

    // Music widget — secondary text (artist name, time labels)
    // Use explicit RGBA values here instead of deriving channels from another
    // color property; QML can coerce those through a string path and collapse
    // the channel reads to black in dark/glass modes.
    readonly property color musicSecondary: (isGlass ? false : effectiveLight)
        ? Qt.rgba(0.102, 0.106, 0.118, 0.55)
        : Qt.rgba(1, 1, 1, 0.55)

    readonly property color weatherForeground: "#ffffff"
    readonly property string weatherIconSet: isGlass ? "mono-light" : "default"
    readonly property color weatherSeparator: isGlass ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.20)
    readonly property color weatherRangeBarBg: isGlass ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.15)
    readonly property color weatherRangeBarFill: isGlass ? Qt.rgba(1, 1, 1, 0.50) : Qt.rgba(1, 1, 1, 0.60)
}
