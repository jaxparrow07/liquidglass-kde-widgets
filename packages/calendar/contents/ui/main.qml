import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.workspace.calendar 2.0 as PlasmaCalendar
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
    onViewYearChanged: {
        rebuildMonthDays();
        _syncCalendarBackends();
        _scheduleRebuildEvents();
    }
    onViewMonthChanged: {
        rebuildMonthDays();
        _syncCalendarBackends();
        _scheduleRebuildEvents();
    }
    onFirstDowChanged: rebuildMonthDays()
    Component.onCompleted: {
        rebuildMonthDays();
        scheduleNextMidnight();
        // Delay initial event load so all three Calendar backends finish their
        // Component.onCompleted (setPluginsManager + goToYearAndMonth) first.
        initialLoadTimer.start();
    }

    Timer {
        id: initialLoadTimer
        interval: 500
        repeat: false
        onTriggered: root._scheduleRebuildEvents()
    }

    // Midnight rollover
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
            root._scheduleRebuildEvents();
        }
    }
    function scheduleNextMidnight() {
        const now = new Date();
        const next = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 5);
        midnightTimer.interval = Math.max(1000, next.getTime() - now.getTime());
        midnightTimer.start();
    }

    // --- Event lookahead preset ---
    readonly property var _lookaheadPresets: [7, 14, 30, 60]
    readonly property int effectiveLookahead: {
        var idx = plasmoid.configuration.eventLookaheadDays;
        return (idx >= 0 && idx < _lookaheadPresets.length) ? _lookaheadPresets[idx] : 30;
    }
    onEffectiveLookaheadChanged: _scheduleRebuildEvents()

    // --- Plasma Calendar backends ---
    PlasmaCalendar.EventPluginsManager {
        id: eventPluginsManager
        enabledPlugins: plasmoid.configuration.enabledCalendarPlugins
        onPluginsChanged: {
            // Plugins take a moment to load and push data into the backends.
            // Use the longer initialLoadTimer so we don't query before data arrives.
            initialLoadTimer.restart();
        }
    }

    // Current-month backend (also tracks viewYear/viewMonth for the grid)
    PlasmaCalendar.Calendar {
        id: calendarBackend
        days: 7
        weeks: 6
        firstDayOfWeek: root.firstDow
        today: root.today
        Component.onCompleted: {
            daysModel.setPluginsManager(eventPluginsManager);
        }
    }

    // Next-month backend for lookahead spanning the month boundary
    PlasmaCalendar.Calendar {
        id: nextMonthBackend
        days: 7
        weeks: 6
        firstDayOfWeek: root.firstDow
        today: root.today
        Component.onCompleted: {
            daysModel.setPluginsManager(eventPluginsManager);
            var d = new Date(root.viewYear, root.viewMonth + 1, 1);
            goToYearAndMonth(d.getFullYear(), d.getMonth() + 1);
        }
    }

    // Third backend: covers the month after next (for 60-day lookahead starting late in a month)
    PlasmaCalendar.Calendar {
        id: thirdMonthBackend
        days: 7
        weeks: 6
        firstDayOfWeek: root.firstDow
        today: root.today
        Component.onCompleted: {
            daysModel.setPluginsManager(eventPluginsManager);
            var d = new Date(root.viewYear, root.viewMonth + 2, 1);
            goToYearAndMonth(d.getFullYear(), d.getMonth() + 1);
        }
    }

    function _syncCalendarBackends() {
        var d1 = new Date(viewYear, viewMonth + 1, 1);
        nextMonthBackend.goToYearAndMonth(d1.getFullYear(), d1.getMonth() + 1);
        var d2 = new Date(viewYear, viewMonth + 2, 1);
        thirdMonthBackend.goToYearAndMonth(d2.getFullYear(), d2.getMonth() + 1);
    }

    // Pick the right DaysModel for a given date
    function _daysModelForDate(d) {
        var m = d.getMonth();
        var y = d.getFullYear();
        if (y === viewYear && m === viewMonth) return calendarBackend.daysModel;
        var nextD = new Date(viewYear, viewMonth + 1, 1);
        if (y === nextD.getFullYear() && m === nextD.getMonth()) return nextMonthBackend.daysModel;
        return thirdMonthBackend.daysModel;
    }

    Connections {
        target: calendarBackend.daysModel
        function onAgendaUpdated() { root._scheduleRebuildEvents(); }
    }
    Connections {
        target: nextMonthBackend.daysModel
        function onAgendaUpdated() { root._scheduleRebuildEvents(); }
    }
    Connections {
        target: thirdMonthBackend.daysModel
        function onAgendaUpdated() { root._scheduleRebuildEvents(); }
    }

    // Debounce rapid re-build signals
    Timer {
        id: rebuildDebounce
        interval: 80
        repeat: false
        onTriggered: root._doRebuildEventsModel()
    }
    function _scheduleRebuildEvents() {
        rebuildDebounce.restart();
    }

    // --- Flat events model (section headers + event cards) ---
    ListModel {
        id: eventsModel
    }

    // Fallback pill colors by event type when the collection has no color set.
    // These are matched against EventDataDecorator.eventType (strings from libcalendarplugin.so).
    readonly property var _eventTypeColors: ({
        "Event":    "#4B9EFF",   // blue  — calendar events
        "Todo":     "#FF9500",   // orange — tasks / todos
        "Journal":  "#34C759",   // green  — journal entries
        "Holiday":  "#FF6B6B"    // red    — public holidays
    })

    function _pillColorFor(ev) {
        var c = ev.eventColor ? ev.eventColor.toString() : "";
        if (c.length > 0 && c !== "#000000" && c !== "#00000000") return c;
        var tc = _eventTypeColors[ev.eventType];
        return tc ? tc : "#0a84ff";
    }

    function _formatTime(ev) {
        if (ev.isAllDay) return "All day";
        return Qt.formatDateTime(ev.startDateTime, "h:mm AP");
    }

    function _formatWeekDate(d) {
        return Qt.formatDateTime(d, "ddd d");
    }

    function _formatUpcomingDate(d) {
        return Qt.formatDateTime(d, "MMM d");
    }

    function _doRebuildEventsModel() {
        eventsModel.clear();

        var now = root.today;
        var todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());

        // End of current week (exclusive): the first day of next week
        // Sun-first: week ends Saturday (day 6), so next week starts Sunday
        // Mon-first: week ends Sunday (day 0), so next week starts Monday
        var weekEndDay = todayStart.getDay(); // 0=Sun..6=Sat
        var daysUntilNextWeek;
        if (firstDow === 1) {
            // Mon-first: last day = Sun (0), next week starts Mon
            daysUntilNextWeek = weekEndDay === 0 ? 1 : (8 - weekEndDay);
        } else {
            // Sun-first: last day = Sat (6), next week starts Sun
            daysUntilNextWeek = weekEndDay === 0 ? 7 : (7 - weekEndDay);
        }
        var weekEnd = new Date(todayStart.getTime() + daysUntilNextWeek * 86400000);

        var lookaheadEnd = new Date(todayStart.getTime() + effectiveLookahead * 86400000);

        var todayEvents = [];
        var weekEvents = [];
        var upcomingEvents = [];
        var seen = {};

        for (var d = new Date(todayStart); d < lookaheadEnd; d = new Date(d.getTime() + 86400000)) {
            var dm = _daysModelForDate(d);
            var rawEvents = dm.eventsForDate(d);
            if (!rawEvents || rawEvents.length === 0) continue;

            // QVariantList → JS array so we can sort
            var events = [];
            for (var ei = 0; ei < rawEvents.length; ei++) events.push(rawEvents[ei]);

            events.sort(function(a, b) {
                if (a.isAllDay && !b.isAllDay) return -1;
                if (!a.isAllDay && b.isAllDay) return 1;
                return a.startDateTime.getTime() - b.startDateTime.getTime();
            });

            for (var i = 0; i < events.length; i++) {
                var ev = events[i];
                // Deduplicate multi-day events
                var key = ev.title + "|" + ev.startDateTime.getTime();
                if (seen[key]) continue;
                seen[key] = true;

                var entry = {
                    isHeader: false,
                    title: ev.title,
                    pillColor: _pillColorFor(ev),
                    isAllDay: ev.isAllDay,
                    timeLabel: ""
                };

                var dTime = d.getTime();
                var todayTime = todayStart.getTime();

                if (dTime === todayTime) {
                    entry.timeLabel = _formatTime(ev);
                    todayEvents.push(entry);
                } else if (d < weekEnd) {
                    entry.timeLabel = _formatWeekDate(d);
                    weekEvents.push(entry);
                } else {
                    entry.timeLabel = _formatUpcomingDate(d);
                    upcomingEvents.push(entry);
                }
            }
        }

        if (todayEvents.length > 0) {
            eventsModel.append({ isHeader: true, title: "Events today", pillColor: "", timeLabel: "", isAllDay: false });
            for (var ti = 0; ti < todayEvents.length; ti++) eventsModel.append(todayEvents[ti]);
        }
        if (weekEvents.length > 0) {
            eventsModel.append({ isHeader: true, title: "This week", pillColor: "", timeLabel: "", isAllDay: false });
            for (var wi = 0; wi < weekEvents.length; wi++) eventsModel.append(weekEvents[wi]);
        }
        if (upcomingEvents.length > 0) {
            eventsModel.append({ isHeader: true, title: "Upcoming", pillColor: "", timeLabel: "", isAllDay: false });
            for (var ui = 0; ui < upcomingEvents.length; ui++) eventsModel.append(upcomingEvents[ui]);
        }

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

            // Empty state
            Text {
                anchors.centerIn: parent
                visible: eventsModel.count === 0
                text: "No upcoming events"
                color: colors.foreground
                font.family: sfRegular.name
                font.pixelSize: full.labelSize
                font.weight: Font.Regular
                opacity: 0.45
                horizontalAlignment: Text.AlignHCenter
            }

            // Section headers + event cards
            ListView {
                id: eventsList
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    topMargin: leftPanel._margin
                    leftMargin: leftPanel._margin
                    rightMargin: leftPanel._margin
                    bottomMargin: leftPanel._margin
                }
                visible: eventsModel.count > 0
                model: eventsModel
                spacing: leftPanel._cardSpacing
                clip: true
                interactive: contentHeight > height

                delegate: Item {
                    width: eventsList.width
                    height: loader.height

                    Loader {
                        id: loader
                        width: parent.width
                        sourceComponent: model.isHeader ? sectionHeaderComponent : eventCardComponent
                        onLoaded: {
                            if (model.isHeader) {
                                item.headerTitle = model.title;
                                item.isFirstHeader = (index === 0);
                            } else {
                                item.cardTitle = model.title;
                                item.cardTime = model.timeLabel;
                                item.cardPill = model.pillColor;
                            }
                        }
                    }
                }
            }

            Component {
                id: sectionHeaderComponent
                Text {
                    property string headerTitle: ""
                    property bool isFirstHeader: false

                    text: headerTitle
                    color: colors.foreground
                    font.family: sfRegular.name
                    font.pixelSize: full.labelSize
                    font.weight: Font.Regular
                    opacity: 0.55
                    font.letterSpacing: 0.5
                    topPadding: isFirstHeader ? 0 : leftPanel._cardSpacing
                    height: Math.round(font.pixelSize * 1.4) + topPadding
                }
            }

            Component {
                id: eventCardComponent
                EventCard {
                    property string cardTitle: ""
                    property string cardTime: ""
                    property string cardPill: ""

                    width: parent ? parent.width : 0
                    title: cardTitle
                    timeLabel: cardTime
                    pillColor: cardPill
                    textColor: colors.foreground
                    fontFamily: sfRegular.name
                    fontSize: leftPanel._cardSize
                    cardBg: colors.cardBackground
                    cardBgOpacity: colors.cardBackgroundOpacity
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

            // --- Month header ---
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
                                punchOutText: colors.punchOutText
                            }
                        }
                    }
                }
            }
        }
    }
}
