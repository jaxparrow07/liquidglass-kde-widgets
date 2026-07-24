import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

ColumnLayout {
    id: root
    spacing: Kirigami.Units.largeSpacing

    property alias cfg_playerFilter: filterField.text
    property alias cfg_filterMode: denyMode.checked
    property alias cfg_autoHideEnabled: autoHideCheck.checked
    property alias cfg_autoHideTimeout: autoHideSpin.value

    Mpris.Mpris2Model { id: mprisModel }

    property var _allowedList: {
        var raw = cfg_playerFilter || ""
        if (raw.trim() === "") return []
        var parts = raw.split(",")
        var list = []
        for (var i = 0; i < parts.length; i++) {
            var id = parts[i].trim()
            if (id !== "") list.push(id)
        }
        return list
    }

    readonly property bool _isDenyMode: cfg_filterMode

    function _isChecked(identity) {
        for (var i = 0; i < root._allowedList.length; i++) {
            if (root._allowedList[i] === identity) return true
        }
        return false
    }

    function _toggle(identity) {
        var list = root._allowedList
        var idx = list.indexOf(identity)
        if (idx >= 0) list.splice(idx, 1)
        else list.push(identity)
        cfg_playerFilter = list.join(",")
    }

    function _reload() {
        playerRepeater.model = 0
        var ids = []
        const CONTAINER_ROLE = Qt.UserRole + 1
        for (var i = 1; i < mprisModel.rowCount(); i++) {
            var player = mprisModel.data(mprisModel.index(i, 0), CONTAINER_ROLE)
            if (player && player.identity) ids.push(player.identity)
        }
        playerRepeater.model = ids
    }

    Component.onCompleted: _reload()

    TextField {
        id: filterField
        visible: false
    }

    Kirigami.FormLayout {
        Layout.fillWidth: true

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Player filter")
        }

        CheckBox {
            id: denyMode
            Kirigami.FormData.label: i18n("Mode:")
            text: i18n("Deny selected players (instead of allowing only selected)")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Detected players:")
            Button {
                icon.name: "view-refresh"
                text: i18n("Refresh")
                onClicked: root._reload()
            }
        }

        Label {
            Layout.fillWidth: true
            text: root._isDenyMode
                ? i18n("Checked players will be ignored by the widget.")
                : i18n("Only checked players are shown. When nothing is checked, all players are shown.")
            wrapMode: Text.WordWrap
            opacity: 0.7
        }

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true

            Repeater {
                id: playerRepeater

                delegate: CheckBox {
                    text: modelData
                    checked: root._isChecked(modelData)
                    onToggled: root._toggle(modelData)
                    Layout.fillWidth: true
                }
            }
        }
    }

    Kirigami.FormLayout {
        Layout.fillWidth: true

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Auto-hide")
        }

        CheckBox {
            id: autoHideCheck
            Kirigami.FormData.label: i18n("When idle:")
            text: i18n("Hide widget when nothing is playing")
        }

        SpinBox {
            id: autoHideSpin
            Kirigami.FormData.label: i18n("Timeout (seconds):")
            enabled: autoHideCheck.checked
            from: 5; to: 3600; stepSize: 5
        }
    }
}
