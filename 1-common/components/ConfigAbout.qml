// Shared "About / More Widgets" config page for every widget in the
// macOS (liquid-glass) widget pack.
//
// Canonical copy lives in 1-common/components/ConfigAbout.qml and is symlinked
// into each package's contents/ui/config/ConfigAbout.qml (matching the repo's
// symlink sharing model). Edit here; every package picks it up on reload.
//
// It lists the other widgets in the set and promotes the companion
// "Nothing" widget pack. Pure presentation — no kcfg entries, so it needs no
// main.xml additions and can be dropped into any package's config.qml as a
// ConfigCategory with source "config/ConfigAbout.qml".

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Outer scroll view gives the page room to breathe and keeps the content
// padded away from the dialog edges at any window size.
Kirigami.ScrollablePage {
    id: page
    padding: Kirigami.Units.gridUnit
    leftPadding: Kirigami.Units.gridUnit * 2
    rightPadding: Kirigami.Units.gridUnit * 2

    // ── Links ─────────────────────────────────────────────────────────────
    readonly property string repoUrl: "https://github.com/jaxparrow07/liquidglass-kde-widgets"
    readonly property string nothingUrl: "https://github.com/jaxparrow07/nothing-kde-widgets"
    readonly property string kofiUrl: "https://ko-fi.com/devrinth"
    readonly property string siteUrl: "https://jackfaithweb.com"
    readonly property string redditUrl: "https://reddit.com/user/zinxyzcool"

    // ── The widgets in this set (names only) ──────────────────────────────
    // Kept in sync by hand with packages/*/metadata.json (test-* widgets and
    // panel-only variants omitted from the customer-facing list).
    readonly property var widgets: [
        { name: i18n("Calendar"),    icon: "view-calendar" },
        { name: i18n("Clock"),       icon: "clock" },
        { name: i18n("World Clock"), icon: "globe" },
        { name: i18n("Timer"),       icon: "chronometer" },
        { name: i18n("Weather"),     icon: "weather-clear" },
        { name: i18n("Music"),       icon: "media-playback-start" }
    ]

    ColumnLayout {
        spacing: Kirigami.Units.gridUnit

        // ── Header ────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 1
                text: i18n("Liquid Glass Widgets")
            }
            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                opacity: 0.7
                text: i18n("A set of macOS-Tahoe style widgets for KDE Plasma, all sharing one liquid-glass backdrop.")
            }
        }

        // ── Widget list (names only) ──────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 3
                text: i18n("Widgets in this set")
            }

            // Wrapping flow of icon + name chips.
            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                Repeater {
                    model: page.widgets
                    delegate: RowLayout {
                        required property var modelData
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.Icon {
                            source: modelData.icon
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        }
                        QQC2.Label {
                            text: modelData.name
                        }
                    }
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                wrapMode: Text.WordWrap
                opacity: 0.7
                textFormat: Text.StyledText
                text: i18n("Browse and install the full set on <a href=\"%1\">GitHub</a>.", page.repoUrl)
                onLinkActivated: (link) => Qt.openUrlExternally(link)
            }
        }

        // ── Companion pack promo (faint dot-matrix backdrop) ──────────────
        Kirigami.Card {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing

            // Nothing OS inspired dot-matrix backdrop, clipped to the card's
            // rounded corners (bg.jpg symlinked from 1-common/icons/about).
            background: Item {
                // Dark base so the corners stay rounded and text stays readable
                // wherever the image is lighter.
                Rectangle {
                    anchors.fill: parent
                    radius: Kirigami.Units.cornerRadius
                    color: "#0a0a0a"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                }

                Item {
                    id: nothingBgMask
                    anchors.fill: parent
                    layer.enabled: true
                    visible: false
                    Rectangle {
                        anchors.fill: parent
                        radius: Kirigami.Units.cornerRadius
                        color: "white"
                    }
                }
                Image {
                    id: nothingBg
                    anchors.fill: parent
                    source: Qt.resolvedUrl("../icons/about/bg.jpg")
                    // Cover: fill the card and crop the overflow, never stretch.
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    mipmap: true
                    cache: true
                    opacity: 0.55
                    // Round the cropped result by masking the Image's own layer,
                    // so PreserveAspectCrop happens before the mask is applied.
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: nothingBgMask
                    }
                }
            }

            contentItem: ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Heading {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.largeSpacing
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    level: 2
                    // Backdrop is always dark, so pin text light regardless of theme.
                    color: "#ffffff"
                    text: i18n("Also try out: Nothing Widgets")
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    wrapMode: Text.WordWrap
                    color: Qt.rgba(1, 1, 1, 0.85)
                    text: i18n("Check out my other widget set. Nothing OS inspired widgets for KDE Plasma.")
                }
                QQC2.Button {
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.bottomMargin: Kirigami.Units.largeSpacing
                    icon.name: "internet-services"
                    text: i18n("Get Nothing Widgets")
                    onClicked: Qt.openUrlExternally(page.nothingUrl)
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
        }

        // ── Support / contact links ───────────────────────────────────────
        Flow {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.largeSpacing

            QQC2.Button {
                // Brand SVG symlinked from 1-common/icons/about (white-filled).
                icon.source: Qt.resolvedUrl("../icons/about/kofi.svg")
                text: i18n("Support on Ko-fi")
                onClicked: Qt.openUrlExternally(page.kofiUrl)
            }
            QQC2.Button {
                icon.name: "globe"
                text: i18n("Website")
                onClicked: Qt.openUrlExternally(page.siteUrl)
            }
            QQC2.Button {
                icon.source: Qt.resolvedUrl("../icons/about/reddit.svg")
                text: i18n("Reddit")
                onClicked: Qt.openUrlExternally(page.redditUrl)
            }
        }
    }
}
