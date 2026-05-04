import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.configuration
import org.kde.plasma.workspace.calendar as PlasmaCalendar

ConfigModel {
    id: configModel

    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-theme"
        source: "config/ConfigAppearance.qml"
    }
    ConfigCategory {
        name: i18n("Calendar")
        icon: "view-calendar"
        source: "config/ConfigGeneral.qml"
    }

    // Dynamically add config pages for each enabled calendar plugin
    // (e.g. PIM Events shows a collection picker, Holidays shows a region picker)
    readonly property PlasmaCalendar.EventPluginsManager _epm: PlasmaCalendar.EventPluginsManager {
        Component.onCompleted: {
            populateEnabledPluginsList(Plasmoid.configuration.enabledCalendarPlugins);
        }
    }

    readonly property Instantiator _pluginPages: Instantiator {
        model: configModel._epm.model
        delegate: ConfigCategory {
            required property string display
            required property string decoration
            required property string configUi
            required property string configModule
            required property string configComponent
            required property string pluginId

            name: display
            icon: decoration
            source: configUi
            configUiModule: configModule
            configUiComponent: configComponent
            visible: Plasmoid.configuration.enabledCalendarPlugins.indexOf(pluginId) > -1
        }

        onObjectAdded: (index, object) => configModel.appendCategory(object)
        onObjectRemoved: (index, object) => configModel.removeCategory(object)
    }
}
