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
    // Per-slot indicator dot color [0..41]; "" means no event/holiday on that day.
    property var dayDots: []
    // Per-slot tooltip text [0..41]; "" means no events/holidays on that day.
    property var dayTitles: []
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
        rebuildDayDots();
    }

    // Event summaries for a grid slot, used for dots and hover tooltips.
    function _eventsForSlot(i) {
        if (!monthDays[i]) return [];
        const d = new Date(viewYear, viewMonth, monthDays[i]);
        const out = [];
        const dm = _daysModelForDate(d);
        const raw = dm.eventsForDate(d);
        if (raw && raw.length > 0) {
            for (let e = 0; e < raw.length; e++) {
                const ev = raw[e];
                out.push({
                    title: ev.title,
                    color: _pillColorFor(ev),
                    isHoliday: ev.eventType === "Holiday"
                });
            }
        }
        const key = _dateKey(d);
        const customs = _parseCustomEvents();
        for (let c = 0; c < customs.length; c++) {
            if (customs[c].date === key) {
                out.push({
                    title: customs[c].title,
                    color: customs[c].color || customEventColor,
                    isHoliday: false
                });
            }
        }
        return out;
    }
    function rebuildDayDots() {
        const dots = new Array(42);
        const titles = new Array(42);
        for (let i = 0; i < 42; i++) {
            const evs = _eventsForSlot(i);
            let color = "";
            for (let e = 0; e < evs.length; e++) {
                if (evs[e].isHoliday) { color = evs[e].color; break; }
            }
            if (!color && evs.length > 0) color = evs[0].color;
            dots[i] = color;
            titles[i] = evs.map(function (ev) { return ev.title; }).join("\n");
        }
        dayDots = dots;
        dayTitles = titles;
    }

    // --- Custom (user-added) events --------------------------------------
    // Stored in plasmoid config as a JSON array of { id, title, date, color },
    // where date is a "yyyy-mm-dd" string (local) and color is a hex string.
    // Always all-day.
    readonly property color customEventColor: "#BF5AF2"

    // Preset event colors (macOS-style), shown as swatches in the add dialog.
    readonly property var customEventPalette: [
        "#FF3B30",   // red
        "#FF9500",   // orange
        "#FFD60A",   // yellow
        "#34C759",   // green
        "#00C7BE",   // teal
        "#0A84FF",   // blue
        "#BF5AF2",   // purple
        "#FF2D55"    // pink
    ]

    property var addEventDate: new Date()
    property string addEventColor: "#BF5AF2"
    property bool addDialogOpen: false

    function _dateKey(d) {
        const m = ("0" + (d.getMonth() + 1)).slice(-2);
        const day = ("0" + d.getDate()).slice(-2);
        return d.getFullYear() + "-" + m + "-" + day;
    }
    function _parseDateKey(key) {
        const p = key.split("-");
        return new Date(parseInt(p[0], 10), parseInt(p[1], 10) - 1, parseInt(p[2], 10));
    }
    function _parseCustomEvents() {
        try {
            const arr = JSON.parse(plasmoid.configuration.customEvents);
            return Array.isArray(arr) ? arr : [];
        } catch (e) {
            return [];
        }
    }
    function _saveCustomEvents(arr) {
        plasmoid.configuration.customEvents = JSON.stringify(arr);
        _scheduleRebuildEvents();
    }
    function _addCustomEvent(title, dateKey, color) {
        const arr = _parseCustomEvents();
        arr.push({ id: Date.now(), title: title, date: dateKey, color: color });
        _saveCustomEvents(arr);
    }
    function _removeCustomEvent(id) {
        const arr = _parseCustomEvents();
        _saveCustomEvents(arr.filter(function (e) { return String(e.id) !== String(id); }));
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
        calendarBackend.goToYearAndMonth(viewYear, viewMonth + 1);
        var d1 = new Date(viewYear, viewMonth + 1, 1);
        nextMonthBackend.goToYearAndMonth(d1.getFullYear(), d1.getMonth() + 1);
        var d2 = new Date(viewYear, viewMonth + 2, 1);
        thirdMonthBackend.goToYearAndMonth(d2.getFullYear(), d2.getMonth() + 1);
    }

    function goPrevMonth() {
        if (viewMonth === 0) {
            viewMonth = 11;
            viewYear -= 1;
        } else {
            viewMonth -= 1;
        }
    }
    function goNextMonth() {
        if (viewMonth === 11) {
            viewMonth = 0;
            viewYear += 1;
        } else {
            viewMonth += 1;
        }
    }
    function goToToday() {
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
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
        if (ev.isAllDay) return i18n("All day");
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

        // When viewing a month other than the current one, list events across
        // the displayed month plus the configured lookahead window (the same
        // "show events for" value used by the current-month view), grouped by
        // month in chronological order.
        if (viewYear !== now.getFullYear() || viewMonth !== now.getMonth()) {
            const customsAll = _parseCustomEvents();
            const seenKeys = {};
            const anchor = new Date(viewYear, viewMonth, 1);
            const end = new Date(anchor.getTime() + effectiveLookahead * 86400000);
            const buckets = [];  // { year, month, entries: [] } in chronological order

            for (let d = new Date(anchor); d < end; d = new Date(d.getTime() + 86400000)) {
                let b = buckets.length > 0 ? buckets[buckets.length - 1] : null;
                if (!b || b.year !== d.getFullYear() || b.month !== d.getMonth()) {
                    b = { year: d.getFullYear(), month: d.getMonth(), entries: [] };
                    buckets.push(b);
                }

                const dm = _daysModelForDate(d);
                const raw = dm.eventsForDate(d);
                if (raw && raw.length > 0) {
                    const evs = [];
                    for (let ei = 0; ei < raw.length; ei++) evs.push(raw[ei]);
                    evs.sort(function(a, b2) {
                        if (a.isAllDay && !b2.isAllDay) return -1;
                        if (!a.isAllDay && b2.isAllDay) return 1;
                        return a.startDateTime.getTime() - b2.startDateTime.getTime();
                    });
                    for (let e = 0; e < evs.length; e++) {
                        const ev = evs[e];
                        const key = ev.title + "|" + ev.startDateTime.getTime();
                        if (seenKeys[key]) continue;
                        seenKeys[key] = true;
                        b.entries.push({
                            isHeader: false,
                            title: ev.title,
                            pillColor: _pillColorFor(ev),
                            isAllDay: ev.isAllDay,
                            timeLabel: _formatWeekDate(d),
                            isCustom: false,
                            eventId: "",
                            sortTime: ev.startDateTime.getTime()
                        });
                    }
                }

                const key2 = _dateKey(d);
                for (let c = 0; c < customsAll.length; c++) {
                    if (customsAll[c].date === key2) {
                        b.entries.push({
                            isHeader: false,
                            title: customsAll[c].title,
                            pillColor: customsAll[c].color || customEventColor,
                            isAllDay: true,
                            timeLabel: _formatWeekDate(d),
                            isCustom: true,
                            eventId: String(customsAll[c].id),
                            sortTime: d.getTime()
                        });
                    }
                }
            }

            const cmp = function(a, b2) {
                if (a.isAllDay && !b2.isAllDay) return -1;
                if (!a.isAllDay && b2.isAllDay) return 1;
                return a.sortTime - b2.sortTime;
            };
            for (let bi = 0; bi < buckets.length; bi++) {
                const b = buckets[bi];
                if (b.entries.length === 0) continue;
                b.entries.sort(cmp);
                eventsModel.append({ isHeader: true, title: monthNames[b.month] + " " + b.year, pillColor: "", timeLabel: "", isAllDay: false });
                for (let e = 0; e < b.entries.length; e++) eventsModel.append(b.entries[e]);
            }
            rebuildDayDots();
            return;
        }

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
                    timeLabel: "",
                    isCustom: false,
                    eventId: "",
                    sortTime: ev.startDateTime.getTime()
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

        // Merge custom (user-added) events into the same buckets.
        var customs = _parseCustomEvents();
        for (var ci = 0; ci < customs.length; ci++) {
            var ce = customs[ci];
            if (!ce.date || !ce.title) continue;
            var cd = _parseDateKey(ce.date);
            if (cd.getTime() < todayStart.getTime() || cd.getTime() >= lookaheadEnd.getTime()) continue;

            var centry = {
                isHeader: false,
                title: ce.title,
                pillColor: ce.color || customEventColor,
                isAllDay: true,
                timeLabel: "",
                isCustom: true,
                eventId: String(ce.id),
                sortTime: cd.getTime()
            };

            if (cd.getTime() === todayStart.getTime()) {
                centry.timeLabel = i18n("All day");
                todayEvents.push(centry);
            } else if (cd < weekEnd) {
                centry.timeLabel = _formatWeekDate(cd);
                weekEvents.push(centry);
            } else {
                centry.timeLabel = _formatUpcomingDate(cd);
                upcomingEvents.push(centry);
            }
        }

        // Re-sort each bucket so custom events land in date order (all-day first).
        var bucketCompare = function(a, b) {
            if (a.isAllDay && !b.isAllDay) return -1;
            if (!a.isAllDay && b.isAllDay) return 1;
            return a.sortTime - b.sortTime;
        };
        todayEvents.sort(bucketCompare);
        weekEvents.sort(bucketCompare);
        upcomingEvents.sort(bucketCompare);

        if (todayEvents.length > 0) {
            eventsModel.append({ isHeader: true, title: i18n("Events today"), pillColor: "", timeLabel: "", isAllDay: false });
            for (var ti = 0; ti < todayEvents.length; ti++) eventsModel.append(todayEvents[ti]);
        }
        if (weekEvents.length > 0) {
            eventsModel.append({ isHeader: true, title: i18n("This week"), pillColor: "", timeLabel: "", isAllDay: false });
            for (var wi = 0; wi < weekEvents.length; wi++) eventsModel.append(weekEvents[wi]);
        }
        if (upcomingEvents.length > 0) {
            eventsModel.append({ isHeader: true, title: i18n("Upcoming"), pillColor: "", timeLabel: "", isAllDay: false });
            for (var ui = 0; ui < upcomingEvents.length; ui++) eventsModel.append(upcomingEvents[ui]);
        }

        rebuildDayDots();
    }

    fullRepresentation: Item {
        id: full
        Layout.preferredWidth:  full.width  > 0 ? full.width  : 200
        Layout.preferredHeight: full.height > 0 ? full.height : 200
        Layout.minimumWidth: 160
        Layout.minimumHeight: 160

        readonly property bool isWide: full.width >= full.height * 2
        readonly property real wideGap: Math.round(full.height * 0.04)
        // Single unified type scale — everything uses this size.
        readonly property real labelSize: Math.max(10, Math.round(full.height * 0.058))

        // The glass squircle's corner is sharper than a plain rounded rect
        // with the same "radius". Convert the config cornerRadius into the
        // equivalent circle radius (matching the superellipse at the 45°
        // apex) so the solid-mode backdrop hugs the widget's corners.
        readonly property real modalBackdropRadius: {
            const n = Math.max(2, plasmoid.configuration.roundnessX10 / 10);
            const factor = (1 - Math.pow(2, -1 / n)) / (1 - Math.pow(2, -0.5));
            return Math.round(plasmoid.configuration.cornerRadius * factor);
        }

        // Hover state for the day-grid tooltip (coordinates in full's space).
        property string dayHoverText: ""
        property real dayHoverCenterX: 0
        property real dayHoverTop: 0

        function confirmAddEvent() {
            const title = addTitleInput.text.trim();
            if (title.length === 0) {
                addTitleInput.forceActiveFocus();
                return;
            }
            root._addCustomEvent(title, root._dateKey(root.addEventDate), root.addEventColor);
            root.addDialogOpen = false;
        }
        function closeAddDialog() {
            root.addDialogOpen = false;
        }

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
                text: i18n("No upcoming events")
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
                                const evId = model.eventId;
                                item.cardTitle = model.title;
                                item.cardTime = model.timeLabel;
                                item.cardPill = model.pillColor;
                                item.cardCustom = model.isCustom === true;
                                item.deleteRequested.connect(function() {
                                    root._removeCustomEvent(evId);
                                });
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
                    property bool cardCustom: false

                    width: parent ? parent.width : 0
                    title: cardTitle
                    timeLabel: cardTime
                    pillColor: cardPill
                    isCustom: cardCustom
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

                Item {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(full.labelSize * 1.4)
                    height: Math.round(full.labelSize * 1.4)

                    Text {
                        anchors.centerIn: parent
                        text: "\u2039"
                        color: colors.foreground
                        opacity: prevMouse.containsMouse ? 1.0 : 0.6
                        font.family: sfRegular.name
                        font.pixelSize: Math.round(full.labelSize * 1.3)
                    }
                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.goPrevMonth()
                    }
                }

                Item {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(full.labelSize * 1.4)
                    height: Math.round(full.labelSize * 1.4)

                    Text {
                        anchors.centerIn: parent
                        text: "\u203A"
                        color: colors.foreground
                        opacity: nextMouse.containsMouse ? 1.0 : 0.6
                        font.family: sfRegular.name
                        font.pixelSize: Math.round(full.labelSize * 1.3)
                    }
                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.goNextMonth()
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.monthNames[root.viewMonth].toUpperCase() + " " + root.viewYear
                    color: colors.todayAccent
                    font.family: sfRegular.name
                    font.pixelSize: full.labelSize
                    font.weight: Font.Regular
                    font.letterSpacing: 1
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.goToToday()
                    }
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
                            readonly property real dotDiameter: Math.max(3, Math.round(full.labelSize * 0.3))

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

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: parent.height / 2 + full.labelSize * 0.55
                                width: dotDiameter
                                height: dotDiameter
                                radius: dotDiameter / 2
                                visible: !empty && !isCurrent && root.dayDots[index] !== ""
                                color: root.dayDots[index] !== "" ? root.dayDots[index] : "transparent"
                            }
                        }
                    }
                }

                MouseArea {
                    id: gridHover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    onEntered: gridHover._update(gridHover.mouseX, gridHover.mouseY)
                    onPositionChanged: (mouse) => gridHover._update(mouse.x, mouse.y)
                    onExited: full.dayHoverText = ""
                    onClicked: (mouse) => gridHover._openAdd(mouse.x, mouse.y)

                    function _update(mx, my) {
                        const col = Math.floor(mx / gridWrap.cellW);
                        const row = Math.floor(my / gridWrap.cellH);
                        const idx = row * 7 + col;
                        if (idx >= 0 && idx < 42 && root.dayTitles[idx] !== "") {
                            const p = mapToItem(full, col * gridWrap.cellW, row * gridWrap.cellH);
                            full.dayHoverText = root.dayTitles[idx];
                            full.dayHoverCenterX = p.x + gridWrap.cellW / 2;
                            full.dayHoverTop = p.y;
                        } else {
                            full.dayHoverText = "";
                        }
                    }

                    function _openAdd(mx, my) {
                        const col = Math.floor(mx / gridWrap.cellW);
                        const row = Math.floor(my / gridWrap.cellH);
                        const idx = row * 7 + col;
                        if (idx < 0 || idx >= 42 || !root.monthDays[idx]) return;
                        full.dayHoverText = "";
                        root.addEventDate = new Date(root.viewYear, root.viewMonth, root.monthDays[idx]);
                        addTitleInput.text = "";
                        root.addDialogOpen = true;
                    }
                }
            }
        }

        // Hover tooltip for day dots (positioned in full's coordinate space).
        Item {
            id: dayTooltip
            visible: full.dayHoverText !== ""
            z: 10

            readonly property real tipPad: Math.round(full.labelSize * 0.55)
            readonly property real maxW: full.width * 0.8
            width: Math.min(tooltipLabel.implicitWidth + 2 * tipPad, maxW)
            height: tooltipLabel.implicitHeight + 2 * tipPad
            x: Math.max(2, Math.min(full.dayHoverCenterX - width / 2, full.width - width - 2))
            y: Math.max(2, full.dayHoverTop - height - Math.round(full.labelSize * 0.35))

            Rectangle {
                anchors.fill: parent
                radius: Math.round(full.labelSize * 0.45)
                color: colors.tooltipBackground
            }

            Text {
                id: tooltipLabel
                anchors.centerIn: parent
                width: dayTooltip.width - 2 * dayTooltip.tipPad
                text: full.dayHoverText
                color: colors.tooltipForeground
                font.family: sfRegular.name
                font.pixelSize: Math.round(full.labelSize * 0.85)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
        }

        // Add-event dialog (opened by clicking a day cell).
        Item {
            id: addDialog
            anchors.fill: parent
            visible: root.addDialogOpen
            z: 20

            onVisibleChanged: {
                if (visible)
                    addFocusTimer.start();
            }

            Timer {
                id: addFocusTimer
                interval: 0
                repeat: false
                onTriggered: addTitleInput.forceActiveFocus()
            }

            Rectangle {
                anchors.fill: parent
                color: "#000000"
                // Glass mode: no dim backdrop (it fights the liquid-glass look).
                // Solid mode: dim, with corners matched to the widget's squircle.
                opacity: colors.isGlass ? 0.0 : 0.35
                radius: colors.isGlass ? 0 : full.modalBackdropRadius
                MouseArea {
                    anchors.fill: parent
                    onClicked: full.closeAddDialog()
                }
            }

            Item {
                id: dialogCard
                anchors.centerIn: parent
                width: Math.min(full.width * 0.8, 340)
                height: dialogColumn.height + 2 * dialogCard.cardPad

                readonly property real cardPad: Math.round(full.labelSize * 0.9)

                LiquidGlass {
                    anchors.fill: parent
                    radius: Math.min(plasmoid.configuration.cornerRadius, 26)
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
                    solidMode: colors.isSolid
                    solidColor: colors.solidBackground
                }

                Column {
                    id: dialogColumn
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: dialogCard.cardPad
                    width: dialogCard.width - 2 * dialogCard.cardPad
                    spacing: Math.round(full.labelSize * 0.45)

                    Text {
                        text: i18n("New Event")
                        color: colors.foreground
                        font.family: sfRegular.name
                        font.pixelSize: full.labelSize
                    }

                    Text {
                        text: Qt.formatDateTime(root.addEventDate, "dddd, MMMM d")
                        color: colors.foreground
                        opacity: 0.6
                        font.family: sfRegular.name
                        font.pixelSize: Math.round(full.labelSize * 0.78)
                    }

                    Item {
                        width: parent.width
                        height: Math.round(full.labelSize * 1.9)

                        Rectangle {
                            anchors.fill: parent
                            radius: Math.round(full.labelSize * 0.4)
                            color: colors.cardBackground
                            opacity: colors.cardBackgroundOpacity
                        }

                        TextInput {
                            id: addTitleInput
                            anchors.fill: parent
                            anchors.leftMargin: Math.round(full.labelSize * 0.5)
                            anchors.rightMargin: Math.round(full.labelSize * 0.5)
                            verticalAlignment: TextInput.AlignVCenter
                            color: colors.foreground
                            font.family: sfRegular.name
                            font.pixelSize: full.labelSize
                            activeFocusOnTab: true
                            selectByMouse: true
                            onAccepted: full.confirmAddEvent()
                            Keys.onEscapePressed: full.closeAddDialog()
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Math.round(full.labelSize * 0.5)
                            anchors.verticalCenter: parent.verticalCenter
                            visible: addTitleInput.text === ""
                            text: i18n("Event title")
                            color: colors.foreground
                            opacity: 0.4
                            font.family: sfRegular.name
                            font.pixelSize: full.labelSize
                        }
                    }

                    Flow {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        spacing: Math.round(full.labelSize * 0.35)

                        Repeater {
                            model: root.customEventPalette
                            delegate: Rectangle {
                                readonly property real swatchSize: Math.round(full.labelSize * 1.3)
                                width: swatchSize
                                height: swatchSize
                                radius: swatchSize / 2
                                color: modelData
                                border.width: root.addEventColor === modelData ? 2 : 0
                                border.color: colors.foreground

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.addEventColor = modelData
                                }
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Math.round(full.labelSize * 0.5)

                        Item {
                            width: Math.round(full.labelSize * 4.2)
                            height: Math.round(full.labelSize * 1.7)

                            Rectangle {
                                anchors.fill: parent
                                radius: Math.round(full.labelSize * 0.5)
                                color: colors.cardBackground
                                opacity: colors.cardBackgroundOpacity
                            }

                            Text {
                                anchors.centerIn: parent
                                text: i18n("Cancel")
                                color: colors.foreground
                                font.family: sfRegular.name
                                font.pixelSize: Math.round(full.labelSize * 0.85)
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: full.closeAddDialog()
                            }
                        }

                        Rectangle {
                            width: Math.round(full.labelSize * 4.2)
                            height: Math.round(full.labelSize * 1.7)
                            radius: Math.round(full.labelSize * 0.5)
                            color: colors.accent

                            Text {
                                anchors.centerIn: parent
                                text: i18n("Add")
                                color: "#ffffff"
                                font.family: sfRegular.name
                                font.pixelSize: Math.round(full.labelSize * 0.85)
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: full.confirmAddEvent()
                            }
                        }
                    }
                }
            }
        }
    }
}
