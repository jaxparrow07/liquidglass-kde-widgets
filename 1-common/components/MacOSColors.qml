import QtQuick
import org.kde.kirigami as Kirigami

QtObject {
    id: macColors

    property int themeMode: 0  // 0=Dark, 1=Light, 2=Follow System

    readonly property bool useSystem: themeMode === 2
    readonly property bool systemIsDark: {
        var bg = Kirigami.Theme.backgroundColor
        var luminance = 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
        return luminance < 0.5
    }
    readonly property bool isLight: themeMode === 1 || (useSystem && !systemIsDark)

    readonly property color background: isLight ? "#f2f2f7" : "#1c1c1e"
    readonly property color surface:    isLight ? "#ffffff" : "#2c2c2e"
    readonly property color surfaceAlt: isLight ? "#e5e5ea" : "#3a3a3c"

    readonly property color labelPrimary:    isLight ? "#000000" : "#ffffff"
    readonly property color labelSecondary:  isLight ? "#3c3c43" : "#ebebf5"
    readonly property color labelTertiary:   isLight ? "#3c3c4399" : "#ebebf599"
    readonly property color labelQuaternary: isLight ? "#3c3c432e" : "#ebebf52e"

    readonly property color accent: "#0a84ff"

    readonly property color separator: isLight ? "#3c3c4336" : "#54545899"

    readonly property color glassTint:      isLight ? "#ffffff" : "#ffffff"
    readonly property real  glassTintAlpha: isLight ? 0.55 : 0.18
    readonly property real  glassFallbackOpacity: isLight ? 0.72 : 0.55
}
