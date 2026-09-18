import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "components"

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
    }

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
        Layout.preferredWidth:  full.width  > 0 ? full.width  : 520
        Layout.preferredHeight: full.height > 0 ? full.height : 220
        Layout.minimumWidth: 340
        Layout.minimumHeight: 160

        readonly property real _margin: Math.round(Math.min(width, height) * 0.10)
        readonly property real _titleSize: Math.max(12, Math.round(height * 0.12))
        readonly property real _subSize: Math.max(10, Math.round(height * 0.085))

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

        // ── Header ──────────────────────────────────────────────────────────
        Column {
            id: header
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

        // ── Heatmap ─────────────────────────────────────────────────────────
        ContributionGraph {
            anchors {
                top: header.bottom
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
