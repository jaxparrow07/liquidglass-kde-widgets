import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "components"
import "widget"

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    MacOSColors {
        id: colors
        styleMode: plasmoid.configuration.styleMode
        appearance: plasmoid.configuration.appearance
    }

    FontLoader { id: sfRegular; source: Qt.resolvedUrl("../fonts/sf_pro_display_regular.otf") }
    FontLoader { id: sfThin; source: Qt.resolvedUrl("../fonts/sf_pro_display_thin.otf") }

    GitHubData {
        id: gh
        username: plasmoid.configuration.username
        fetchProfile: true
    }

    readonly property string _displayName: gh.login !== ""
        ? gh.login
        : plasmoid.configuration.username.trim()

    readonly property string _monogram: _displayName !== ""
        ? _displayName.charAt(0).toUpperCase()
        : "?"

    function formatCount(n) {
        var s = String(n)
        var out = ""
        while (s.length > 3) {
            out = "," + s.slice(-3) + out
            s = s.slice(0, -3)
        }
        return s + out
    }

    fullRepresentation: Item {
        id: full
        Layout.preferredWidth:  full.width  > 0 ? full.width  : 560
        Layout.preferredHeight: full.height > 0 ? full.height : 260
        Layout.minimumWidth: 360
        Layout.minimumHeight: 200

        // Wide enough for the heatmap and the account info to sit side by side.
        readonly property bool isWide: full.width >= full.height * 1.6

        readonly property real _margin: Math.round(Math.min(width, height) * 0.10)
        readonly property real _titleSize: Math.max(12, Math.round(Math.min(width, height) * 0.14))
        readonly property real _subSize: Math.max(10, Math.round(Math.min(width, height) * 0.085))
        readonly property real _avatarSize: Math.max(30, Math.round(Math.min(width, height) * 0.30))
        readonly property real _accountW: Math.round(_avatarSize * 1.6)
        readonly property real _accountH: Math.round(_avatarSize * 1.4)

        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: plasmoid.configuration.cornerRadius
            roundness: plasmoid.configuration.roundnessX10 / 10
            refractThickness: plasmoid.configuration.refractThickness
            refractIOR: plasmoid.configuration.refractIORx100 / 100
            refractScale: plasmoid.configuration.refractScale
            tint: colors.glassTint
            tintAlpha: plasmoid.configuration.tintAlphaPct / 100
            chromaStrength: plasmoid.configuration.chromaStrengthPct / 100
            specStrength: plasmoid.configuration.specStrengthPct / 100
            blurRadius: plasmoid.configuration.blurRadiusPx
            realtimeRefraction: plasmoid.configuration.realtimeRefraction
            fallbackOpacity: colors.glassFallbackOpacity
            solidMode: colors.isSolid
            solidColor: colors.solidBackground
        }

        // ── Account info panel (top in tall mode, right in wide mode) ──────
        Item {
            id: accountPanel
            x: full.isWide ? full.width - full._accountW : 0
            y: 0
            width: full.isWide ? full._accountW : full.width
            height: full.isWide ? full.height : full._accountH

            // Tall mode: avatar left, username right, on one row.
            Row {
                anchors.centerIn: parent
                visible: !full.isWide
                spacing: Math.round(full._avatarSize * 0.28)

                Avatar {
                    id: avatarRow
                    width: full._avatarSize
                    height: full._avatarSize
                    anchors.verticalCenter: parent.verticalCenter
                    source: gh.avatarUrl
                    fallbackText: root._monogram
                    textColor: colors.foreground
                    borderColor: Qt.rgba(colors.foreground.r, colors.foreground.g, colors.foreground.b, 0.25)
                    fontFamily: sfRegular.name
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root._displayName
                    color: colors.foreground
                    font.family: sfRegular.name
                    font.pixelSize: Math.max(11, Math.round(full._avatarSize * 0.40))
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    width: Math.max(1, accountPanel.width - full._avatarSize * 1.6)
                }
            }

            // Wide mode: avatar on top, username below.
            Column {
                anchors.centerIn: parent
                visible: full.isWide
                spacing: Math.round(full._avatarSize * 0.16)

                Avatar {
                    id: avatarColumn
                    width: full._avatarSize
                    height: full._avatarSize
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: gh.avatarUrl
                    fallbackText: root._monogram
                    textColor: colors.foreground
                    borderColor: Qt.rgba(colors.foreground.r, colors.foreground.g, colors.foreground.b, 0.25)
                    fontFamily: sfRegular.name
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: full._accountW
                    horizontalAlignment: Text.AlignHCenter
                    text: root._displayName
                    color: colors.foreground
                    font.family: sfRegular.name
                    font.pixelSize: Math.max(10, Math.round(full._avatarSize * 0.30))
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }

        // ── Contribution panel (below in tall mode, left in wide mode) ─────
        Item {
            id: contribPanel
            x: 0
            y: full.isWide ? 0 : full._accountH
            width: full.isWide ? full.width - full._accountW : full.width
            height: full.isWide ? full.height : full.height - full._accountH

            Column {
                id: contribHeader
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: full._margin
                    leftMargin: full._margin
                    rightMargin: full._margin
                }
                visible: gh.cells.length > 0
                spacing: Math.round(full._margin * 0.15)

                Text {
                    width: parent.width
                    text: i18n("Contributions")
                    color: colors.foreground
                    font.family: sfRegular.name
                    font.pixelSize: full._titleSize
                    font.weight: Font.Medium
                    font.letterSpacing: 0.4
                    opacity: 0.92
                }

                Text {
                    width: parent.width
                    text: gh.totalCount === 1
                        ? i18n("1 contribution in the last year")
                        : i18n("%1 contributions in the last year", root.formatCount(gh.totalCount))
                    color: colors.foreground
                    font.family: sfThin.name
                    font.pixelSize: full._subSize
                    opacity: 0.55
                }
            }

            ContributionGraph {
                anchors {
                    top: contribHeader.bottom
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    topMargin: Math.round(full._margin * 0.6)
                    leftMargin: full._margin
                    rightMargin: full._margin
                    bottomMargin: full._margin
                }
                visible: gh.cells.length > 0
                cells: gh.cells
                foreground: colors.foreground
                levels: colors.contributionLevels
                fontFamily: sfRegular.name
            }
        }

        // ── Status text (empty / error) ────────────────────────────────────
        Text {
            anchors.centerIn: parent
            width: parent.width - full._margin * 2
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: !gh.isLoading && gh.cells.length === 0
            text: {
                if (plasmoid.configuration.username.trim() === "")
                    return i18n("Set your GitHub username in the widget settings")
                if (gh.errorMessage !== "")
                    return gh.errorMessage
                return i18n("No contribution data")
            }
            color: colors.foreground
            font.family: sfRegular.name
            font.pixelSize: full._subSize
            opacity: 0.6
        }

        // ── Loading spinner ─────────────────────────────────────────────────
        MacSpinner {
            anchors.centerIn: parent
            width: Math.round(Math.min(full.width, full.height) * 0.14)
            height: width
            running: gh.isLoading
            visible: running
            color: colors.foreground
            z: 5
        }

        // ── Click to refresh ────────────────────────────────────────────────
        MouseArea {
            anchors.fill: parent
            z: 10
            acceptedButtons: Qt.LeftButton
            propagateComposedEvents: true
            onClicked: {
                gh.forceRefresh()
                mouse.accepted = false
            }
        }
    }
}
