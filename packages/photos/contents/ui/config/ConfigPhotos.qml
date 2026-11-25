import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils

KCMUtils.SimpleKCM {
    id: page

    property alias cfg_folder: folderField.text
    property alias cfg_intervalMinutes: intervalSpin.value
    property alias cfg_shuffle: shuffleCheck.checked

    readonly property string picturesPath:
        StandardPaths.writableLocation(StandardPaths.PicturesLocation).toString().replace(/^file:\/\//, "")

    Kirigami.FormLayout {
        RowLayout {
            Kirigami.FormData.label: i18n("Folder:")
            QQC2.TextField {
                id: folderField
                Layout.minimumWidth: Kirigami.Units.gridUnit * 14
                placeholderText: page.picturesPath
            }
            QQC2.Button {
                icon.name: "document-open-folder"
                text: i18n("Browse…")
                onClicked: folderDialog.open()
            }
        }

        QQC2.Label {
            text: i18n("Leave empty to use your Pictures folder. Subfolders are not included.")
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            opacity: 0.7
        }

        QQC2.SpinBox {
            id: intervalSpin
            Kirigami.FormData.label: i18n("Change photo every:")
            from: 1
            to: 1440
            textFromValue: (v) => i18np("%1 minute", "%1 minutes", v)
            valueFromText: (t) => parseInt(t) || 1
        }

        QQC2.CheckBox {
            id: shuffleCheck
            Kirigami.FormData.label: i18n("Order:")
            text: i18n("Shuffle")
        }
    }

    FolderDialog {
        id: folderDialog
        currentFolder: "file://" + (folderField.text || page.picturesPath)
        onAccepted: folderField.text = decodeURIComponent(selectedFolder.toString().replace(/^file:\/\//, ""))
    }
}
