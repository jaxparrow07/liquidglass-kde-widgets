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

    FontLoader {
        id: sfRegular
        source: Qt.resolvedUrl("../fonts/sf_pro_display_regular.otf")
    }

    // --- Date state ---
    property date today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth() // 0..11

    // First day of week: 0 = Sunday, 1 = Monday
    readonly property int firstDow: plasmoid.configuration.firstDayOfWeek

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var weekdayShortSun: ["S", "M", "T", "W", "T", "F", "S"]
    readonly property var weekdayShortMon: ["M", "T", "W", "T", "F", "S", "S"]
    readonly property var weekdayShort: firstDow === 1 ? weekdayShortMon : weekdayShortSun

    // Column [0..6] → is this a Sat/Sun column, given the current firstDow?
    function isWeekendCol(col) {
        return firstDow === 1 ? (col === 5 || col === 6) // Mon-first: cols 5,6 = Sat,Sun
        : (col === 0 || col === 6); // Sun-first: cols 0,6 = Sun,Sat
    }

    // Precomputed day-of-month per grid slot [0..41]; 0 means empty.
    // Recomputed only when (viewYear, viewMonth, firstDow) changes —
    // delegates read from this instead of calling Date() 42× per redraw.
    property var monthDays: []
    function rebuildMonthDays() {
        const firstOfMonth = new Date(viewYear, viewMonth, 1);
        let offset = firstOfMonth.getDay() - firstDow;
        if (offset < 0)
            offset += 7;
        const lastDay = new Date(viewYear, viewMonth + 1, 0).getDate();
        const out = new Array(42);
        for (let i = 0; i < 42; i++) {
            const day = i - offset + 1;
            out[i] = (day < 1 || day > lastDay) ? 0 : day;
        }
        monthDays = out;
    }
    onViewYearChanged: rebuildMonthDays()
    onViewMonthChanged: rebuildMonthDays()
    onFirstDowChanged: rebuildMonthDays()
    Component.onCompleted: {
        rebuildMonthDays();
        scheduleNextMidnight();
    }

    // Midnight rollover: fire once exactly at next local midnight, then
    // update state and reschedule. Much cheaper than polling.
    Timer {
        id: midnightTimer
        repeat: false
        onTriggered: {
            const n = new Date();
            root.today = n;
            if (n.getFullYear() !== root.viewYear)
                root.viewYear = n.getFullYear();
            if (n.getMonth() !== root.viewMonth)
                root.viewMonth = n.getMonth();
            root.scheduleNextMidnight();
        }
    }
    function scheduleNextMidnight() {
        const now = new Date();
        const next = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 5);
        midnightTimer.interval = Math.max(1000, next.getTime() - now.getTime());
        midnightTimer.start();
    }

    ListModel {
        id: eventsModel
        ListElement { title: "Team Standup"; timeLabel: "9:00 AM"; pillColor: "#FF6B6B" }
        ListElement { title: "Lunch Break"; timeLabel: "12:00 PM"; pillColor: "#4ECDC4" }
        ListElement { title: "Design Review"; timeLabel: "2:30 PM"; pillColor: "#45B7D1" }
        ListElement { title: "Focus Time"; timeLabel: "4:00 PM"; pillColor: "#96CEB4" }
    }

    fullRepresentation: Item {
        id: full
        Layout.preferredWidth: 200
        Layout.preferredHeight: 200
        Layout.minimumWidth: 160
        Layout.minimumHeight: 160

        readonly property bool isWide: full.width >= full.height * 2
        readonly property real wideGap: Math.round(full.height * 0.04)
        // Single unified type scale — everything uses this size.
        readonly property real labelSize: Math.max(10, Math.round(full.height * 0.058))

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
            realtimeRefraction: plasmoid.configuration.realtimeRefraction
            fallbackOpacity: colors.glassFallbackOpacity
            solidMode: colors.isSolid
            solidColor: colors.solidBackground
        }

        // ── Left panel: Events (wide mode only) ───────────────────────────
        Item {
            id: leftPanel
            visible: full.isWide
            anchors {
                top: parent.top
                left: parent.left
                bottom: parent.bottom
                right: rightPanel.left
                rightMargin: full.wideGap
            }

            readonly property real _margin: Math.round(full.height * 0.09)
            readonly property real _cardSize: Math.max(10, Math.round(full.height * 0.052))
            readonly property real _cardSpacing: Math.round(full.height * 0.025)

            Text {
                id: eventsTitle
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: leftPanel._margin
                    leftMargin: leftPanel._margin
                }
                text: "Events"
                color: colors.foreground
                font.family: sfRegular.name
                font.pixelSize: full.labelSize
                font.weight: Font.Regular
                opacity: 0.55
                font.letterSpacing: 0.5
            }

            ListView {
                id: eventsList
                anchors {
                    top: eventsTitle.bottom
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    topMargin: leftPanel._cardSpacing
                    leftMargin: leftPanel._margin
                    rightMargin: leftPanel._margin
                    bottomMargin: leftPanel._margin
                }
                model: eventsModel
                spacing: leftPanel._cardSpacing
                clip: true
                interactive: false

                delegate: EventCard {
                    width: eventsList.width
                    title: model.title
                    timeLabel: model.timeLabel
                    pillColor: model.pillColor
                    textColor: colors.foreground
                    fontFamily: sfRegular.name
                    fontSize: leftPanel._cardSize
                    isGlass: colors.isGlass
                    isLight: colors.isLight
                }
            }
        }

        // ── Right panel: Calendar grid ────────────────────────────────────
        Item {
            id: rightPanel
            width: full.isWide ? full.height : full.width
            anchors {
                top: parent.top
                right: parent.right
                bottom: parent.bottom
            }
        }

        ColumnLayout {
            parent: rightPanel
            anchors.fill: parent
            anchors.margins: Math.round(full.height * 0.09)
            anchors.topMargin: Math.round(full.height * 0.14)
            spacing: Math.round(full.height * 0.02)

            // --- Month header — left edge aligned with the optical left
            //     edge of the "S" below (first column's center minus half
            //     the "S" width).
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: full.labelSize * 1.4

                TextMetrics {
                    id: sMetrics
                    font.family: sfRegular.name
                    font.pixelSize: full.labelSize
                    text: root.weekdayShort[0]
                }

                Text {
                    x: parent.width / 7 / 2 - sMetrics.width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.monthNames[root.viewMonth].toUpperCase()
                    color: colors.foreground
                    font.family: sfRegular.name
                    font.pixelSize: full.labelSize
                    font.weight: Font.Regular
                    font.letterSpacing: 1
                }
            }

            // --- Weekday header (S M T W T F S) ---
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: full.labelSize * 1.4

                Row {
                    anchors.fill: parent
                    Repeater {
                        model: 7
                        delegate: Item {
                            width: parent.width / 7
                            height: parent.height
                            Text {
                                anchors.centerIn: parent
                                text: root.weekdayShort[index]
                                color: colors.foreground
                                opacity: root.isWeekendCol(index) ? 0.45 : 0.75
                                font.family: sfRegular.name
                                font.pixelSize: full.labelSize
                                font.weight: Font.Regular
                            }
                        }
                    }
                }
            }

            // --- Day grid: 6 rows × 7 columns ---
            Item {
                id: gridWrap
                Layout.fillWidth: true
                Layout.fillHeight: true

                readonly property real cellW: width / 7
                readonly property real cellH: height / 6
                readonly property real badgeDiameter: Math.min(cellW, cellH) * 1.02

                Grid {
                    id: dayGrid
                    anchors.fill: parent
                    rows: 6
                    columns: 7

                    Repeater {
                        model: 42
                        delegate: Item {
                            width: gridWrap.cellW
                            height: gridWrap.cellH

                            readonly property int day: root.monthDays[index] || 0
                            readonly property bool empty: day === 0
                            readonly property bool isCurrent: !empty && day === root.today.getDate() && root.viewMonth === root.today.getMonth() && root.viewYear === root.today.getFullYear()
                            readonly property bool isWeekend: root.isWeekendCol(index % 7)

                            Text {
                                anchors.centerIn: parent
                                visible: !empty && !isCurrent
                                text: day
                                color: colors.foreground
                                opacity: isWeekend ? 0.45 : 1.0
                                font.family: sfRegular.name
                                font.pixelSize: full.labelSize
                                font.weight: Font.Regular
                            }

                            TodayBadge {
                                anchors.centerIn: parent
                                width: parent.width + gridWrap.badgeDiameter * 0.30
                                height: parent.height + gridWrap.badgeDiameter * 0.30
                                visible: isCurrent
                                contentRect: Qt.rect((width - parent.width) / 2, (height - parent.height) / 2, parent.width, parent.height)
                                dayNumber: day
                                diameter: gridWrap.badgeDiameter
                                circleXOffset: full.labelSize * 0.04
                                circleYOffset: -full.labelSize * 0.05
                                fontPixelSize: full.labelSize
                                fontFamily: sfRegular.name
                                badgeColor: colors.todayAccent
                                textColor: "#ffffff"
                                punchOutText: colors.isGlass
                            }
                        }
                    }
                }
            }
        }
    }
}
