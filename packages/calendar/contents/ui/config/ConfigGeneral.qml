import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    property alias cfg_firstDayOfWeek: firstDayCombo.currentIndex

    ComboBox {
        id: firstDayCombo
        Kirigami.FormData.label: i18n("First day of week:")
        model: [i18n("Sunday"), i18n("Monday")]
    }
}
