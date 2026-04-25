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
    readonly property bool isLight: appearance === 1 || (useSystem && !systemIsDark)
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

    // Foreground used by widget content. Glass stays monochromatic white
    // so the translucent shader keeps its existing look regardless of
    // appearance; Solid follows light/dark inversion.
    readonly property color foreground: isGlass ? "#ffffff" : solidForeground

    // Today/highlight accent: white in Glass (monochrome) and red in Solid.
    readonly property color todayAccent: isGlass ? "#ffffff" : accentRed
}
