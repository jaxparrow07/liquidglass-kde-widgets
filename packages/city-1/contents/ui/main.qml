import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "components"
import "widget"

// City I — world clock built on clock-analog's full-numeral dial.
//
// 1x1  : a single dial (the city's time) + code above / hour-diff below center.
//        Themed by the widget appearance, no day/night flip.
// 2x2  : up to 4 dials, no perimeter ring (numerals at hour positions), each
//        disc flips light(day)/dark(night) by that city's local time. City code
//        below each face.
// 4x2  : same faces in a row; below each, NAME + day word + hour-diff.
//
// The OUTER squircle is solid-dark by default; "Fully opaque background" OFF
// turns it to glass. The inner discs keep their own day/night colors regardless.

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    MacOSColors {
        id: colors
        styleMode: plasmoid.configuration.styleMode
        appearance: plasmoid.configuration.appearance
    }

    // Real light/dark independent of glass (mirrors clock-analog-2): drives the
    // 1x1 disc plate so it reads correctly in every mode.
    readonly property bool _realLight: plasmoid.configuration.appearance === 1
        || (plasmoid.configuration.appearance === 2 && !colors.systemIsDark)

    FontLoader {
        id: sfProRounded
        source: Qt.resolvedUrl("../fonts/sf_pro_rounded.otf")
    }

    fullRepresentation: Item {
        id: full
        Layout.preferredWidth:  full.width  > 0 ? full.width  : 200
        Layout.preferredHeight: full.height > 0 ? full.height : 200
        Layout.minimumWidth: 160
        Layout.minimumHeight: 160

        WorldClock {
            id: world
            clocks: plasmoid.configuration.clocks
            // Seconds sweep in every mode (single + grid faces show a second hand).
            needsSeconds: true
            active: full.visible
        }

        // --- Layout state ---
        readonly property int _count: Math.max(1, Math.min(world.count, 4))
        readonly property bool _single: _count <= 1
        readonly property bool _wide: !_single && width >= height * 2
        // Grid columns: single->1, wide->one row, else 2-wide grid.
        readonly property int _cols: _single ? 1 : (_wide ? _count : 2)

        // Day/night disc palette for grid faces (per city).
        function _discColor(isDay) { return isDay ? "#ffffff" : "#343436" }
        function _markColor(isDay) { return isDay ? "#1A1B1E" : "#ffffff" }

        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: plasmoid.configuration.cornerRadius
            roundness: plasmoid.configuration.roundnessX10 / 10
            refractThickness: plasmoid.configuration.refractThickness
            refractIOR: plasmoid.configuration.refractIORx100 / 100
            refractScale: plasmoid.configuration.refractScale
            tint: colors.glassTint
            tintAlpha: plasmoid.configuration.tintAlphaPct / 100
            chromaStrength: plasmoid.configuration.chromaStrengthPct / 100
            specStrength: plasmoid.configuration.specStrengthPct / 100
            blurRadius: plasmoid.configuration.blurRadiusPx
            realtimeRefraction: plasmoid.configuration.realtimeRefraction
            fallbackOpacity: colors.glassFallbackOpacity
            // Solid style keeps the glass material as the backdrop by default;
            // only "Fully opaque background" reverts to a flat dark fill.
            solidMode: colors.isSolid && plasmoid.configuration.opaqueBackground
            solidColor: "#1A1B1E"
        }

        // ==================== SINGLE (1x1) ====================
        Item {
            id: singleView
            anchors.fill: parent
            visible: full._single

            readonly property var e: world.entries.length ? world.entries[0] : null
            readonly property real _r: Math.min(width, height) * 0.42

            ClockFace {
                anchors.fill: parent
                anchors.margins: Math.min(full.width, full.height) * 0.08
                fontFamily: sfProRounded.name
                ringStyle: "perimeter"
                showSeconds: true
                hourAngle:   singleView.e ? singleView.e.hourAngle : 0
                minuteAngle: singleView.e ? singleView.e.minuteAngle : 0
                secondAngle: world.sweepAngle
                // Always show the disc in solid mode (matches clock-analog): the
                // marks are foreground-colored, so they need the contrasting plate
                // — white in light, #343436 in dark — even when the outer card is
                // the flat opaque #1A1B1E fill. Hiding it left dark marks on the
                // dark card (invisible) in solid light + opaque background.
                discVisible: true
                discColor: colors.isGlass ? Qt.rgba(1, 1, 1, 0.20)
                                          : (root._realLight ? "#ffffff" : "#343436")
                markColor: colors.foreground
                numeralOpacity:   colors.isGlass ? 0.85 : 1.0
                handOpacity:      colors.isGlass ? 0.92 : 1.0
            }

            // Code above the hinge, offset (number only, e.g. "+12") below it —
            // centered as a group, same color/opacity as the dial numerals.
            readonly property real _annoFont: Math.max(8, singleView._r * 0.16)
            readonly property real _annoInset: singleView._r * 0.40
            // Match City Digital's lowered annotation opacity (both modes).
            readonly property real _annoOpacity: (colors.isGlass ? 0.55 : 1.0) * 0.55

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height / 2 - singleView._annoInset - height / 2
                text: singleView.e ? singleView.e.code : ""
                font.family: sfProRounded.name
                font.pixelSize: singleView._annoFont
                font.weight: Font.Medium
                color: colors.foreground
                opacity: singleView._annoOpacity
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height / 2 + singleView._annoInset - height / 2
                // Number only, no "HRS".
                text: singleView.e ? singleView.e.offsetLabel.replace("HRS", "") : ""
                font.family: sfProRounded.name
                font.pixelSize: singleView._annoFont
                font.weight: Font.Medium
                color: colors.foreground
                opacity: singleView._annoOpacity
            }
        }

        // ==================== GRID (2x2) / ROW (4x2) ====================
        GridLayout {
            id: grid
            anchors.fill: parent
            anchors.margins: Math.round(Math.min(full.width, full.height) * 0.06)
            visible: !full._single
            columns: full._cols
            // Tighter gap between clocks than the outer padding.
            rowSpacing: Math.round(anchors.margins * 0.4)
            columnSpacing: Math.round(anchors.margins * 0.4)

            Repeater {
                // Bind to a stable COUNT, not the entries array. `world.entries`
                // is reassigned wholesale every second, which would tear down and
                // recreate every delegate (Canvas faces vanish/reappear → the
                // "blinking"). With an int model the delegates persist and only
                // the live `modelData` binding below re-evaluates.
                model: full._single ? 0 : world.count

                delegate: Item {
                    id: cell
                    required property int index
                    readonly property var modelData: world.entries[index] || ({})
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    readonly property bool wide: full._wide
                    // Wide (4x2): reserve space below the face for the NAME/day/
                    // offset block. Grid (2x2): code goes INSIDE the face, so the
                    // face fills the whole cell (centered).
                    readonly property real infoH: wide ? Math.round(height * 0.34) : 0
                    // Inset between the face and its cell edges: 10px in the 2x2
                    // grid, and a small wide-mode inset so adjacent 4x2 faces don't
                    // crowd each other (margin between faces — faces stay full size).
                    readonly property real _faceInset: wide ? Math.round(width * 0.08) : 10
                    readonly property real faceSize: Math.max(0, Math.min(width - _faceInset, height - infoH))

                    // Group the face + (wide) label and center it in the cell. The
                    // group height is the face plus the label's REAL content height
                    // (not the infoH reservation) so centerIn centers the visible
                    // block instead of leaving dead space below the text.
                    Item {
                        id: group
                        width: cell.faceSize
                        height: cell.faceSize + (cell.wide ? cityLabel.fullContentHeight
                                                                 + Math.round(cell.faceSize * 0.04)
                                                           : 0)
                        anchors.centerIn: parent

                        ClockFace {
                            id: gridFace
                            width: cell.faceSize
                            height: cell.faceSize
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            fontFamily: sfProRounded.name
                            ringStyle: "numeralsOnly"
                            showSeconds: true
                            // Grid faces step the second hand once per second
                            // (per-city secondAngle), not the 60fps sweep — the
                            // simultaneous per-frame Canvas repaints across all
                            // faces is what caused the blinking.
                            secondAngle: cell.modelData.secondAngle
                            hourAngle:   cell.modelData.hourAngle
                            minuteAngle: cell.modelData.minuteAngle
                            discVisible: true
                            discColor: full._discColor(cell.modelData.isDay)
                            markColor: full._markColor(cell.modelData.isDay)
                            numeralOpacity: 0.85
                            handOpacity: 0.92
                        }

                        // City code INSIDE the face, toward the TOP (same edge
                        // margin the bottom placement used), code only.
                        Text {
                            anchors.horizontalCenter: gridFace.horizontalCenter
                            y: gridFace.y + cell.faceSize * 0.30 - height / 2
                            text: cell.modelData.code
                            font.family: sfProRounded.name
                            font.pixelSize: Math.max(7, cell.faceSize * 0.13)
                            font.weight: Font.Medium
                            color: full._markColor(cell.modelData.isDay)
                            opacity: (colors.isGlass ? 0.55 : 1.0) * 0.55
                        }

                        // Wide (4x2) only: NAME + day word + offset below the face.
                        CityLabel {
                            id: cityLabel
                            visible: cell.wide
                            anchors.top: gridFace.bottom
                            anchors.topMargin: Math.round(cell.faceSize * 0.04)
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: fullContentHeight
                            mode: "full"
                            fontFamily: sfProRounded.name
                            code: cell.modelData.code
                            // Prefer the user's typed label; it already falls
                            // back to the resolved city name when left blank.
                            name: cell.modelData.label
                            dayWord: cell.modelData.dayWord
                            offsetLabel: cell.modelData.offsetLabel
                            textColor: colors.foreground
                            primaryOpacity:   1.0
                            secondaryOpacity: colors.isGlass ? 0.85 : 0.6
                            baseFontSize: Math.max(8, cell.faceSize * 0.13)
                        }
                    }
                }
            }
        }
    }
}
