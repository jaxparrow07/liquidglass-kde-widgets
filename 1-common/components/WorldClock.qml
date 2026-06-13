import QtQuick
import org.kde.plasma.clock as PlasmaClock
import "cities.js" as Cities

// Non-visual world-clock model for the City widgets.
//
// Timezone/DST math is handled entirely by the system: each configured city
// gets an `org.kde.plasma.clock` Clock object (C++ QTimeZone-backed, signal
// driven, DST-correct). We never compute zone offsets ourselves — we only
// read each Clock's `dateTime` / `timeZoneOffset` and turn them into the plain
// numbers/strings the faces and labels consume.
//
// `clocks` config is a list of "tz|label" strings. Each entry resolves to:
//   tz, label, code, name,
//   hourAngle, minuteAngle, secondAngle  (degrees, for analog hands)
//   hour12, minute, second, ampm         (for digital readout)
//   offsetLabel  ("+9HRS" / "-8HRS" / "0HRS", vs. local)
//   dayWord      ("Yesterday" / "Today" / "Tomorrow", vs. local date)
//   isDay        (true when 06:00 <= local hour < 18:00)
//
// `entries` is reassigned wholesale whenever any clock ticks so QML bindings
// re-evaluate. Repeaters bind `model: world.entries`.

Item {
    id: root

    // Raw config: array of "tz|label" strings (or a comma-joined string on some
    // KDE versions). An empty/blank tz means "system local time".
    property var clocks: []

    // When true, Clocks track seconds (tick every second) so the digital second
    // value advances; the analog second hand uses `sweepAngle` for smoothness.
    property bool needsSeconds: false

    // Sleep updates when the widget isn't visible.
    property bool active: true

    // Published, fully-resolved list (see header). Read-only to consumers.
    property var entries: []
    readonly property int count: entries.length

    // Smoothly-sweeping second-hand angle (degrees), universal wall seconds.
    // Seconds are identical across all real zones, so one local sweep is exact.
    property real sweepAngle: 0

    // --- Parsing -------------------------------------------------------------

    // Normalize `clocks` into [{ tz, label, code, name }]. Label falls back to
    // the resolved city name when the user left it blank.
    function _parseClocks() {
        var raw = clocks;
        if (typeof raw === "string")
            raw = raw.length ? raw.split(",") : [];
        if (!raw)
            raw = [];

        var out = [];
        for (var i = 0; i < raw.length; i++) {
            var s = String(raw[i]);
            var bar = s.indexOf("|");
            var tz = (bar >= 0 ? s.slice(0, bar) : s).trim();
            // Skip blank entries (e.g. a leftover "|") — no empty clock faces.
            if (!tz) continue;
            var label = bar >= 0 ? s.slice(bar + 1).trim() : "";
            var info = Cities.lookup(tz);
            out.push({
                tz: tz,
                label: label.length ? label : info.name,
                code: info.code,
                name: info.name
            });
        }
        return out;
    }

    // Base config records (tz/label/code/name); the Instantiator mirrors this.
    property var _base: []
    function _reparse() { _base = _parseClocks(); }

    // --- Offset parsing ------------------------------------------------------

    // Convert a Clock `timeZoneOffset` string ("UTC+09:00", "UTC-07:00",
    // "UTC") into whole hours, truncated toward zero so a +09:30 zone reads +9.
    function _offsetHoursFromString(s) {
        if (!s) return 0;
        var m = String(s).match(/UTC([+-])(\d{1,2}):?(\d{2})?/);
        if (!m) return 0;
        var sign = m[1] === "-" ? -1 : 1;
        return sign * parseInt(m[2], 10);
    }

    // Difference of a zone's offset vs. local offset, in (possibly fractional)
    // hours. Kept fractional so half-hour zones (India +5:30, Nepal +5:45,
    // etc.) read correctly against each other — e.g. Tokyo vs India is +3.5.
    function _relHours(zoneOffsetStr) {
        var localMin = -(new Date().getTimezoneOffset());      // minutes east of UTC
        var localHr  = localMin / 60;
        var zoneHr   = _offsetHoursFromStringFractional(zoneOffsetStr);
        return zoneHr - localHr;
    }

    // Fractional hours from "UTC+09:30" etc. (keeps the :30 for the diff math).
    function _offsetHoursFromStringFractional(s) {
        if (!s) return 0;
        var m = String(s).match(/UTC([+-])(\d{1,2}):?(\d{2})?/);
        if (!m) return 0;
        var sign = m[1] === "-" ? -1 : 1;
        var h = parseInt(m[2], 10);
        var mm = m[3] ? parseInt(m[3], 10) : 0;
        return sign * (h + mm / 60);
    }

    function _offsetLabel(relHrs) {
        var sign = relHrs > 0 ? "+" : (relHrs < 0 ? "-" : "");
        var abs  = Math.abs(relHrs);
        // Trim trailing ".0" but keep ".5" / ".75" for fractional-offset zones.
        var num  = (abs % 1 === 0) ? abs.toString()
                                   : abs.toFixed(2).replace(/0+$/, "").replace(/\.$/, "");
        return sign + num + "HRS";
    }

    // Day word for a zone's date vs. local date.
    function _dayWord(zoneDate) {
        var now = new Date();
        var z = Date.UTC(zoneDate.getFullYear(), zoneDate.getMonth(), zoneDate.getDate());
        var l = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());
        var diff = Math.round((z - l) / 86400000);
        if (diff < 0) return "Yesterday";
        if (diff > 0) return "Tomorrow";
        return "Today";
    }

    // --- Rebuild -------------------------------------------------------------
    //
    // Reads every live Clock object held by the Instantiator and republishes
    // `entries`. Triggered by each Clock's timeChanged / timeZoneChanged.

    function _rebuild() {
        var out = [];
        for (var i = 0; i < clockRepeater.count; i++) {
            var item = clockRepeater.objectAt(i);
            if (!item || i >= _base.length)
                continue;
            var b = _base[i];
            var clk = item.clock;
            var dt = clk.dateTime;          // QDateTime in the target zone's wall time

            var h = dt.getHours();
            var m = dt.getMinutes();
            var s = dt.getSeconds();
            var min = m + s / 60;
            var hr  = (h % 12) + min / 60;
            var h12 = ((h + 11) % 12) + 1;
            var rel = _relHours(clk.timeZoneOffset);

            out.push({
                tz: b.tz, label: b.label, code: b.code, name: b.name,
                hourAngle:   hr  / 12 * 360,
                minuteAngle: min / 60 * 360,
                secondAngle: (s / 60) * 360,
                hour12: h12,
                minute: m,
                second: s,
                ampm: h < 12 ? "AM" : "PM",
                offsetLabel: _offsetLabel(rel),
                dayWord: _dayWord(dt),
                isDay: h >= 6 && h < 18
            });
        }
        entries = out;
    }

    // One system Clock per configured city. Each is C++/QTimeZone-backed and
    // emits timeChanged on its own schedule (incl. across DST transitions).
    Instantiator {
        id: clockRepeater
        model: root._base

        delegate: QtObject {
            required property var modelData
            readonly property var clock: clockObj
            property QtObject clockObj: PlasmaClock.Clock {
                timeZone: modelData.tz
                trackSeconds: root.needsSeconds
                onTimeChanged: root._rebuild()
                onTimeZoneChanged: root._rebuild()
            }
        }
        onCountChanged: root._rebuild()
        onObjectAdded: root._rebuild()
    }

    // Smooth second-hand sweep (analog 1x1 only). Universal seconds off the
    // local wall clock; gated on needsSeconds so other views pay nothing.
    Timer {
        interval: 16
        repeat: true
        running: root.active && root.needsSeconds
        onTriggered: root.sweepAngle = ((Date.now() % 60000) / 60000) * 360
    }

    onClocksChanged: _reparse()
    Component.onCompleted: {
        _reparse();
        sweepAngle = ((Date.now() % 60000) / 60000) * 360;
    }
}
