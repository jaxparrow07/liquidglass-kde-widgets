import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root
    implicitWidth: content.implicitWidth + Kirigami.Units.largeSpacing * 4
    implicitHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 4

    property string cfg_username: ""

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing * 2
        spacing: Kirigami.Units.largeSpacing

        Label {
            Layout.fillWidth: true
            text: i18n("GitHub username")
            font.bold: true
        }

        Label {
            Layout.fillWidth: true
            text: i18n("Enter the GitHub username whose yearly contribution graph you want to display.")
            wrapMode: Text.WordWrap
            opacity: 0.75
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }

        TextField {
            id: usernameField
            Layout.fillWidth: true
            placeholderText: i18n("e.g. torvalds")

            Component.onCompleted: text = root.cfg_username
            onTextChanged: root.cfg_username = text
        }

        Item { Layout.fillHeight: true }

        Label {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            text: i18n("Contributions are read from the public GitHub profile page (github.com/users/<username>/contributions). No account, OAuth or access token is required.")
            wrapMode: Text.WordWrap
            opacity: 0.6
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }
    }
}
