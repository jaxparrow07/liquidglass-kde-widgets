import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "styleCodec.js" as StyleCodec
import "links.js" as Links

// Right-click menu entries shared by every widget. Use as:
//   WidgetActions { id: commonActions }
//   Plasmoid.contextualActions: commonActions.list   // or extras.concat(commonActions.list)
Item {
    id: actions

    readonly property bool hasStyle: plasmoid.configuration.styleMode !== undefined

    // Reads the clipboard through a hidden text field (no QML clipboard API).
    QQC2.TextField {
        id: clipboardBridge
        visible: false
    }

    readonly property PlasmaCore.Action separatorTop: PlasmaCore.Action { isSeparator: true }
    readonly property PlasmaCore.Action separatorBottom: PlasmaCore.Action { isSeparator: true }

    readonly property PlasmaCore.Action glassToggle: PlasmaCore.Action {
        text: i18n("Glass Style")
        icon.name: "preferences-desktop-theme-global"
        checkable: true
        checked: plasmoid.configuration.styleMode === 0
        // Hidden while the style follows the windows on screen.
        visible: actions.hasStyle && !plasmoid.configuration.autoStyle
        onTriggered: checked => plasmoid.configuration.styleMode = checked ? 0 : 1
    }

    readonly property PlasmaCore.Action pasteStyle: PlasmaCore.Action {
        text: i18n("Apply Copied Style")
        icon.name: "edit-paste"
        visible: actions.hasStyle
        onTriggered: {
            clipboardBridge.text = ""
            clipboardBridge.paste()
            StyleCodec.apply(plasmoid.configuration, clipboardBridge.text)
        }
    }

    readonly property PlasmaCore.Action support: PlasmaCore.Action {
        text: i18n("Buy Me a Coffee")
        // Action icons only take a theme name or an absolute file path.
        icon.name: Qt.resolvedUrl("../icons/about/bmc-accent.svg").toString().replace(/^file:\/\//, "")
        // Not opened directly: on Wayland a browser is only brought to the
        // front when the app that opens it hands over an activation token,
        // and Qt can only request one from a window that has input focus.
        // Right after a context menu closes no window does, so the browser
        // would open behind everything. The dialog is a real focused window,
        // and its button click supplies the token. (The settings dialog's
        // About page already is such a window, so it opens links directly.)
        onTriggered: supportDialog.show()
    }

    Window {
        id: supportDialog
        title: i18n("Buy Me a Coffee")
        // Fixed size; every limit derives from one value, so there is no
        // width/height <-> minimum/maximum binding loop.
        readonly property real _w: Kirigami.Units.gridUnit * 20
        readonly property real _h: dialogColumn.implicitHeight + Kirigami.Units.gridUnit * 3
        width: _w
        height: _h
        minimumWidth: _w
        maximumWidth: _w
        minimumHeight: _h
        maximumHeight: _h
        flags: Qt.Dialog
        color: Kirigami.Theme.backgroundColor
        // True from the click until the dialog closes itself.
        property bool _opening: false
        onVisibleChanged: if (visible) {
            _opening = false
            x = Screen.virtualX + (Screen.width - width) / 2
            y = Screen.virtualY + (Screen.height - height) / 2
            requestActivate()
        }

        // Qt asks the compositor for the activation token asynchronously and
        // only launches the browser once it arrives. Closing this window
        // right after Qt.openUrlExternally() destroys the token request and
        // the launch silently never happens (still reported as success), so
        // the window stays open for a moment after the click.
        Timer {
            id: closeAfterLaunch
            interval: 2500
            onTriggered: supportDialog.close()
        }

        Kirigami.Theme.colorSet: Kirigami.Theme.Window
        Kirigami.Theme.inherit: false

        ColumnLayout {
            id: dialogColumn
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                margins: Kirigami.Units.gridUnit * 1.5
            }
            spacing: Kirigami.Units.largeSpacing

            QQC2.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.bold: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                color: Kirigami.Theme.textColor
                text: i18n("Support Liquid Glass Widgets")
            }

            QQC2.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: Kirigami.Theme.textColor
                opacity: 0.8
                text: supportDialog._opening
                    ? i18n("Opening your browser…")
                    : i18n("This opens buymeacoffee.com in your web browser. Thanks for considering it!")
            }

            // Official button artwork, used as-is (same as the settings page).
            Image {
                Layout.alignment: Qt.AlignHCenter
                source: Qt.resolvedUrl("../icons/about/bmc-button.svg")
                sourceSize.height: Kirigami.Units.gridUnit * 2.5
                fillMode: Image.PreserveAspectFit
                smooth: true
                opacity: supportDialog._opening ? 0.5 : (bmcMouse.containsMouse ? 0.9 : 1.0)

                MouseArea {
                    id: bmcMouse
                    anchors.fill: parent
                    enabled: !supportDialog._opening
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        supportDialog._opening = true
                        const ok = Qt.openUrlExternally(Links.bmc)
                        // Logged so a failed launch can be diagnosed from
                        // `journalctl --user -b | grep "Liquid Glass"`.
                        console.log("Liquid Glass: open", Links.bmc, "->", ok ? "handed to the system" : "FAILED")
                        closeAfterLaunch.restart()
                    }
                }
            }

            QQC2.Button {
                Layout.alignment: Qt.AlignHCenter
                text: supportDialog._opening ? i18n("Close") : i18n("Not now")
                onClicked: supportDialog.close()
            }
        }
    }

    readonly property var list: [separatorTop, glassToggle, pasteStyle, separatorBottom, support]
}
