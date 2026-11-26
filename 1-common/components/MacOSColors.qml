import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.taskmanager as TaskManager
import org.kde.kwindowsystem

QtObject {
    id: macColors

    // Two orthogonal axes:
    //   styleMode:  0 = Glass (translucent shader),  1 = Solid (opaque fill)
    //   appearance: 0 = Dark, 1 = Light, 2 = Follow system
    property int styleMode: 0
    property int appearance: 0
    // autoStyle overrides styleMode: Solid while the desktop has
    // focus, Glass while a window does (macOS Tahoe).
    property bool autoStyle: false
    // Not in panels: there is no desktop behind the widget to follow.
    readonly property bool _auto: autoStyle
        && Plasmoid.formFactor !== PlasmaCore.Types.Horizontal
        && Plasmoid.formFactor !== PlasmaCore.Types.Vertical

    readonly property bool useSystem: appearance === 2
    readonly property bool systemIsDark: {
        var bg = Kirigami.Theme.backgroundColor
        var luminance = 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
        return luminance < 0.5
    }
    readonly property bool isLight: !isGlass && (appearance === 1 || (useSystem && !systemIsDark))
    // wantGlass is the requested style; isGlass is the one shown. They only
    // differ for the moment a StyleFade (if the widget has one) needs to
    // snapshot the old style before the switch. isGlass must not be bound to
    // wantGlass: the binding would switch the style before the snapshot.
    readonly property bool wantGlass: _auto ? !desktopFocused : styleMode === 0
    property bool isGlass: false
    Component.onCompleted: isGlass = wantGlass
    readonly property bool isSolid: !isGlass
    property Item fader: null
    onWantGlassChanged: {
        if (fader) fader.run()
        else isGlass = wantGlass
    }

    // Whether the desktop, rather than a window, has focus. Latched: panel
    // popups, the launcher and context menus take focus from both, so they
    // leave it as it was instead of flipping the style.
    property bool desktopFocused: true

    // The desktop window behind the widget. The wallpaper item is used to
    // reach it, since a QtObject has no window of its own.
    readonly property bool _desktopActive: {
        if (!_auto || !Plasmoid.containment) return false
        const w = Plasmoid.containment.wallpaperGraphicsObject
        return w instanceof Item && w.Window.active
    }
    // Nothing to focus but the desktop: no visible window on any screen, or
    // "Show Desktop" is on (KWin doesn't minimize the windows for it).
    readonly property bool _desktopClear: KWindowSystem.showingDesktop
        || !_windows.item || _windows.item.count === 0
    readonly property bool _windowActive: _windows.item !== null && _windows.item.activeTask.valid

    on_DesktopActiveChanged: _updateFocus()
    on_DesktopClearChanged: _updateFocus()
    on_WindowActiveChanged: _updateFocus()

    function _updateFocus() {
        if (_desktopActive || _desktopClear) desktopFocused = true
        else if (_windowActive) desktopFocused = false
    }

    // Not filtered by screen: focus is global. The model only exists while
    // autoStyle is on, so other widgets pay nothing for it.
    readonly property Loader _windows: Loader {
        active: macColors._auto
        sourceComponent: TaskManager.TasksModel {
            filterByCurrentVirtualDesktop: true
            filterByActivity: true
            filterHidden: true
            filterMinimized: true
            activity: _activityInfo.currentActivity
            sortMode: TaskManager.TasksModel.SortDisabled
            groupMode: TaskManager.TasksModel.GroupDisabled
        }
    }
    readonly property TaskManager.ActivityInfo _activityInfo: TaskManager.ActivityInfo {}

    // Glass-mode counterpart of isLight: true when the user picked Light
    // (or the system theme is light under Follow system) while in Glass
    // style. Kept as its own axis rather than folded into isLight so the
    // many existing `isGlass ? a : b` branches in widget code (which never
    // considered a light glass) keep their current dark-glass behavior;
    // only the tokens below that actually govern the glass tint/foreground
    // read this.
    readonly property bool glassIsLight: isGlass && (appearance === 1 || (useSystem && !systemIsDark))

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
    readonly property color glassTint: glassIsLight ? "#ffffff" : "#000000"
    readonly property real  glassTintAlpha: glassIsLight ? 0.60 : 0.32
    readonly property real  glassFallbackOpacity: glassIsLight ? 0.72 : 0.55

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
        : (isGlass ? glassIsLight : isLight)

    // Foreground used by widget content. Glass follows glassIsLight (a
    // light glass tint needs dark content to stay legible); Solid follows
    // the ordinary light/dark inversion.
    readonly property color foreground: isGlass ? (glassIsLight ? "#1A1B1E" : "#ffffff") : (effectiveLight ? "#1A1B1E" : "#ffffff")

    // Photos widget: full color in solid; in glass the photo goes monochrome
    // and lets the glass show through, like macOS Tahoe's tinted widgets.
    readonly property real photoSaturation: isGlass ? -1.0 : 0.0
    readonly property real photoOpacity: isGlass ? 0.75 : 1.0
    // Photos widget empty state (macOS Tahoe): black card with the colored
    // app tile in solid; in glass the tile turns translucent white and the
    // flower monochrome.
    readonly property color photosSolidBackground: "#000000"
    readonly property bool photosIconMonochrome: isGlass
    readonly property color photosIconTileTop: isGlass ? Qt.rgba(1, 1, 1, 0.20) : "#3a3a3a"
    readonly property color photosIconTileBottom: isGlass ? Qt.rgba(1, 1, 1, 0.10) : "#1e1e1e"
    readonly property color photosIconTileBorder: isGlass ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12)
    readonly property real photosPlaceholderOpacity: isGlass ? 0.4 : 0.58

    // Today/highlight accent: white on dark glass, red otherwise.
    readonly property color todayAccent: isGlass ? (glassIsLight ? accentRed : "#ffffff") : accentRed

    // Badge punch-out: glass uses destination-out compositing, solid uses normal text.
    readonly property bool punchOutText: isGlass

    // Card backgrounds — white on dark modes, black on light modes (solid
    // light, or a light glass tint).
    readonly property bool  _cardLight:            isLight || glassIsLight
    readonly property color cardBackground:        _cardLight ? "#000000" : "#ffffff"
    readonly property real  cardBackgroundOpacity: _cardLight ? 0.08 : 0.10
    readonly property real  cardHoverOpacity:      _cardLight ? 0.14 : 0.17
    readonly property real  cardPressOpacity:      _cardLight ? 0.20 : 0.22

    // Timer action colors — solid-filled in glass, tinted in solid.
    readonly property color countdownText:  isGlass ? (glassIsLight ? "#FF8B00" : "#ffffff") : "#FF8B00"
    readonly property color actionGreen:    "#00A832"
    readonly property color actionOrange:   "#FF8E00"
    readonly property color buttonIcon:     isGlass ? (glassIsLight ? "#1A1B1E" : "#ffffff") : solidForeground
    readonly property color cancelButtonBg: isGlass
        ? (glassIsLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.25))
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
    readonly property color musicSecondary: effectiveLight
        ? Qt.rgba(0.102, 0.106, 0.118, 0.55)
        : Qt.rgba(1, 1, 1, 0.55)

    readonly property color weatherForeground: "#ffffff"
    readonly property string weatherIconSet: isGlass ? (glassIsLight ? "mono-dark" : "mono-light") : "default"
    readonly property color weatherSeparator: isGlass ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.20)
    readonly property color weatherRangeBarBg: isGlass ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.15)
    readonly property color weatherRangeBarFill: isGlass ? Qt.rgba(1, 1, 1, 0.50) : Qt.rgba(1, 1, 1, 0.60)
}
