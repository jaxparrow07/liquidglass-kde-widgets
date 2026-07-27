import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
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

    FontLoader { id: sfLight;   source: Qt.resolvedUrl("../fonts/SF-Pro-Display-Light.otf") }
    FontLoader { id: sfRegular; source: Qt.resolvedUrl("../fonts/sf_pro_display_regular.otf") }

    BatteryData {
        id: batteryData
    }

    fullRepresentation: Item {
        id: full

        Layout.preferredWidth: 200
        Layout.preferredHeight: 200
        Layout.minimumWidth: 120
        Layout.minimumHeight: 120

        readonly property real _minSide: Math.min(width, height)
        readonly property real labelSize: Math.max(10, Math.round(_minSide * 0.065))

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
            solidColor: colors.isSolid ? "#34C759" : colors.solidBackground
            solidColorBottom: colors.isSolid ? "#1A5C2E" : "transparent"
        }

        Item {
            anchors.fill: parent
            anchors.margins: Math.round(full._minSide * 0.06)

            Item {
                id: batteryIndicator
                anchors.top: parent.top
                anchors.left: parent.left
                width: Math.min(parent.width * 0.4, parent.height * 0.4)
                height: width
                anchors.topMargin: 0
                anchors.leftMargin: 0

                Canvas {
                    id: progressCircle
                    anchors.fill: parent

                    property real progress: batteryData.percentage / 100
                    property color arcColor: "#ffffff"

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()

                        var cx = width / 2
                        var cy = height / 2
                        var r = Math.min(width, height) / 2 - 6
                        var lw = Math.max(6, r * 0.22)

                        ctx.beginPath()
                        ctx.arc(cx, cy, r, 0, Math.PI * 2)
                        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.18)
                        ctx.lineWidth = lw
                        ctx.stroke()

                        if (progress > 0) {
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(progress, 1))
                            ctx.strokeStyle = arcColor
                            ctx.lineWidth = lw
                            ctx.lineCap = "round"
                            ctx.stroke()
                        }
                    }

                    Connections {
                        target: batteryData
                        function onPercentageChanged() { progressCircle.requestPaint() }
                        function onBatteryColorChanged() { progressCircle.requestPaint() }
                    }
                }

                Kirigami.Icon {
                    id: laptopIcon
                    anchors.centerIn: parent
                    source: "computer-laptop"
                    color: "#ffffff"
                    width: Math.round(parent.width * 0.6)
                    height: width
                }
            }

            Text {
                id: bigPercent
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                text: batteryData.percentage + "%"
                color: "#ffffff"
                opacity: 0.60
                font.family: sfRegular.name
                font.pixelSize: Math.round(full._minSide * 0.3)
                font.weight: Font.Bold
            }
        }
    }
}
