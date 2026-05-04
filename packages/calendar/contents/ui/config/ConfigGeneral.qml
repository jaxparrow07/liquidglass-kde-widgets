import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    property alias cfg_firstDayOfWeek: firstDayCombo.currentIndex
    property alias cfg_eventLookaheadDays: lookaheadCombo.currentIndex

    // StringList — Plasma config passes this as a JS array.
    property var cfg_enabledCalendarPlugins: []

    function _applyPluginsToCheckboxes() {
        var list = cfg_enabledCalendarPlugins;
        // May arrive as an array or as a comma-joined string depending on KDE version.
        if (typeof list === "string") list = list.split(",").map(function(s) { return s.trim(); });
        pimCheck.checked          = list.indexOf("pimevents") !== -1;
        holidaysCheck.checked     = list.indexOf("holidaysevents") !== -1;
        astronomicalCheck.checked = list.indexOf("astronomicalevents") !== -1;
    }

    function _applyCheckboxesToPlugins() {
        var parts = [];
        if (pimCheck.checked)          parts.push("pimevents");
        if (holidaysCheck.checked)     parts.push("holidaysevents");
        if (astronomicalCheck.checked) parts.push("astronomicalevents");
        cfg_enabledCalendarPlugins = parts;
    }

    // Populate checkboxes once config value is available.
    onCfg_enabledCalendarPluginsChanged: _applyPluginsToCheckboxes()

    ComboBox {
        id: firstDayCombo
        Kirigami.FormData.label: i18n("First day of week:")
        model: [i18n("Sunday"), i18n("Monday")]
    }

    ComboBox {
        id: lookaheadCombo
        Kirigami.FormData.label: i18n("Show events for:")
        model: [i18n("7 days"), i18n("14 days"), i18n("30 days"), i18n("60 days")]
    }

    Item {
        Kirigami.FormData.label: i18n("Calendar sources:")
        implicitHeight: pluginsColumn.implicitHeight
        implicitWidth: pluginsColumn.implicitWidth

        ColumnLayout {
            id: pluginsColumn
            spacing: 4

            CheckBox {
                id: pimCheck
                text: i18n("PIM Events (Akonadi)")
                onCheckedChanged: _applyCheckboxesToPlugins()
            }
            CheckBox {
                id: holidaysCheck
                text: i18n("Holidays")
                onCheckedChanged: _applyCheckboxesToPlugins()
            }
            CheckBox {
                id: astronomicalCheck
                text: i18n("Astronomical Events")
                onCheckedChanged: _applyCheckboxesToPlugins()
            }
        }
    }
}
