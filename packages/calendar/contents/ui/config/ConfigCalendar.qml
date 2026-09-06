// Calendar settings: one sidebar entry with General / Events tabs.
//
// The Events tab is ConfigPimEvents.qml, loaded through a Loader so that a
// missing kpim6-kdepim-addons (which provides org.kde.plasma.PimCalendars)
// only breaks that tab, not the whole page. The config dialog only talks
// to this page, so saveConfig() and configurationChanged are forwarded to
// and from the loaded Events page.
//
// Plasma's own plugin pages (Holidays, Astronomical events, ...) are not
// merged here; they stay separate sidebar entries (see config.qml).

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils

KCMUtils.AbstractKCM {
    id: root

    property alias cfg_firstDayOfWeek: firstDayCombo.currentIndex
    property alias cfg_eventLookaheadDays: lookaheadCombo.currentIndex
    property alias cfg_autoFontSize: autoFontCheck.checked
    property alias cfg_gridFontSize: gridFontSpin.value
    property alias cfg_eventFontSize: eventFontSpin.value

    // StringList — Plasma config passes this as a JS array.
    property var cfg_enabledCalendarPlugins: []

    signal configurationChanged

    function saveConfig() {
        if (eventsLoader.item && eventsLoader.item.saveConfig)
            eventsLoader.item.saveConfig()
    }

    function _applyPluginsToCheckboxes() {
        let list = cfg_enabledCalendarPlugins
        // May arrive as an array or as a comma-joined string depending on KDE version.
        if (typeof list === "string") list = list.split(",").map(s => s.trim())
        pimCheck.checked          = list.indexOf("pimevents") !== -1
        holidaysCheck.checked     = list.indexOf("holidaysevents") !== -1
        astronomicalCheck.checked = list.indexOf("astronomicalevents") !== -1
    }

    function _applyCheckboxesToPlugins() {
        const parts = []
        if (pimCheck.checked)          parts.push("pimevents")
        if (holidaysCheck.checked)     parts.push("holidaysevents")
        if (astronomicalCheck.checked) parts.push("astronomicalevents")
        cfg_enabledCalendarPlugins = parts
    }

    // Populate checkboxes once config value is available.
    onCfg_enabledCalendarPluginsChanged: _applyPluginsToCheckboxes()

    // Tabs run edge to edge, like other KDE tabbed settings pages.
    headerPaddingEnabled: false
    header: QQC2.TabBar {
        id: tabBar
        objectName: "configTabBar"
        // A lone "General" tab is just noise; only show tabs when there are two.
        visible: pimCheck.checked
        QQC2.TabButton { text: i18n("General") }
        QQC2.TabButton {
            text: i18n("Events")
            // Follows the checkbox live, so enabling PIM events shows the tab
            // before Apply is pressed.
            visible: pimCheck.checked
            width: visible ? implicitWidth : 0
        }
    }

    // Don't leave the hidden Events tab selected.
    Connections {
        target: pimCheck
        function onCheckedChanged() { if (!pimCheck.checked) tabBar.currentIndex = 0 }
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: tabBar.currentIndex

        // ── General ───────────────────────────────────────────────────────
        QQC2.ScrollView {
            contentWidth: availableWidth

            Kirigami.FormLayout {
                width: parent.width

                QQC2.ComboBox {
                    id: firstDayCombo
                    Kirigami.FormData.label: i18n("First day of week:")
                    model: [i18n("Sunday"), i18n("Monday")]
                }

                QQC2.ComboBox {
                    id: lookaheadCombo
                    Kirigami.FormData.label: i18n("Show events for:")
                    model: [i18n("7 days"), i18n("14 days"), i18n("30 days"), i18n("60 days")]
                }

                // One checkbox per row, label on the first only (KDE style).
                QQC2.CheckBox {
                    id: pimCheck
                    Kirigami.FormData.label: i18n("Calendar sources:")
                    text: i18n("PIM Events (Akonadi)")
                    onToggled: root._applyCheckboxesToPlugins()
                }
                QQC2.CheckBox {
                    id: holidaysCheck
                    text: i18n("Holidays")
                    onToggled: root._applyCheckboxesToPlugins()
                }
                QQC2.CheckBox {
                    id: astronomicalCheck
                    text: i18n("Astronomical Events")
                    onToggled: root._applyCheckboxesToPlugins()
                }

                QQC2.Label {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                    wrapMode: Text.WordWrap
                    opacity: 0.75
                    text: pimCheck.checked
                        ? i18n("Choose which Akonadi calendars to show in the Events tab. Holidays and Astronomical Events have their own pages in the sidebar.")
                        : i18n("Holidays and Astronomical Events have their own pages in the sidebar once enabled.")
                }

                Kirigami.Separator {
                    Kirigami.FormData.isSection: true
                    Kirigami.FormData.label: i18n("Text size")
                }

                QQC2.CheckBox {
                    id: autoFontCheck
                    Kirigami.FormData.label: i18n("Scaling:")
                    text: i18n("Scale text with widget size")
                }

                QQC2.Label {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                    wrapMode: Text.WordWrap
                    opacity: 0.75
                    text: i18n("With scaling off, making the widget taller shows more events instead of larger text.")
                }

                QQC2.SpinBox {
                    id: gridFontSpin
                    Kirigami.FormData.label: i18n("Calendar grid (px):")
                    from: 8; to: 48; stepSize: 1
                    enabled: !autoFontCheck.checked
                }

                QQC2.SpinBox {
                    id: eventFontSpin
                    Kirigami.FormData.label: i18n("Event list (px):")
                    from: 8; to: 48; stepSize: 1
                    enabled: !autoFontCheck.checked
                }
            }
        }

        // ── Events (Akonadi collections) ──────────────────────────────────
        Item {
            Loader {
                id: eventsLoader
                anchors.fill: parent
                // Only load once PIM events are enabled; the import needs
                // kpim6-kdepim-addons.
                active: pimCheck.checked
                source: "ConfigPimEvents.qml"
            }

            Connections {
                target: eventsLoader.item
                ignoreUnknownSignals: true
                function onConfigurationChanged() { root.configurationChanged() }
            }

            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.gridUnit * 4
                visible: eventsLoader.status === Loader.Error
                icon.name: "view-calendar"
                text: i18n("Calendar events aren't available")
                explanation: i18n("Install the kpim6-kdepim-addons package to show events from your calendars (Akonadi).")
            }
        }
    }
}
