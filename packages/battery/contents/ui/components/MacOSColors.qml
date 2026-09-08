import QtQuick
import org.kde.kirigami as Kirigami

QtObject {
    id: macColors

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
    readonly property color solidBackground: isLight ? "#ffffff" : "#1A1B1E"
    readonly property color solidForeground: isLight ? "#1A1B1E" : "#ffffff"

    readonly property color glassTint: isLight ? "#ffffff" : "#000000"
    readonly property real  glassTintAlpha: isLight ? 0.60 : 0.32
    readonly property real  glassFallbackOpacity: isLight ? 0.72 : 0.55

    readonly property color foreground: isGlass ? "#ffffff" : (isLight ? "#1A1B1E" : "#ffffff")
}
