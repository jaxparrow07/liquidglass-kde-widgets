import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.notification
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

    FontLoader { id: sfThin;    source: Qt.resolvedUrl("../fonts/sf_pro_display_thin.otf") }
    FontLoader { id: sfRegular; source: Qt.resolvedUrl("../fonts/sf_pro_display_regular.otf") }

    // ── State ─────────────────────────────────────────────────────────────
    // 0 = IDLE, 1 = RUNNING, 2 = PAUSED, 3 = FINISHED
    property int  timerState: 0
    property int  selectedMinutes: 0
    property int  selectedSeconds: 0
    property real remainingMs: 0
    property real targetTime: 0
    property real totalMs: 0

    readonly property int displayMinutes: Math.floor(remainingMs / 60000)
    readonly property int displaySeconds: Math.floor((remainingMs % 60000) / 1000)

    // ── Countdown tick ────────────────────────────────────────────────────
    Timer {
        id: countdownTick
        interval: 100
        repeat: true
        running: root.timerState === 1 && !startDelayTimer.running
        onTriggered: {
            var now = Date.now()
            root.remainingMs = Math.max(0, root.targetTime - now)
            if (root.remainingMs === 0) {
                root.timerState = 3
                timerFinishedNotification.sendEvent()
            }
        }
    }

    // Delay between pressing Start and the countdown actually beginning —
    // gives the RollingDigit entrance animations time to play first
    Timer {
        id: startDelayTimer
        interval: 420
        repeat: false
        onTriggered: root.targetTime = Date.now() + root.remainingMs
    }

    Notification {
        id: timerFinishedNotification
        componentName: "plasma_workspace"
        eventId: "notification"
        title: "Timer"
        text: "Time's up!"
        urgency: Notification.NormalUrgency
    }

    // ── State transitions ─────────────────────────────────────────────────
    function startTimer() {
        var ms = (selectedMinutes * 60 + selectedSeconds) * 1000
        if (ms <= 0) return
        totalMs = ms
        remainingMs = ms
        timerState = 1
        startDelayTimer.restart()
    }

    function pauseTimer() {
        remainingMs = Math.max(0, targetTime - Date.now())
        timerState = 2
    }

    function resumeTimer() {
        targetTime = Date.now() + remainingMs
        timerState = 1
    }

    function cancelTimer() {
        startDelayTimer.stop()
        timerState = 0
        remainingMs = 0
    }

    // ── UI ────────────────────────────────────────────────────────────────
    fullRepresentation: Item {
        id: full
        Layout.preferredWidth: 200
        Layout.preferredHeight: 200
        Layout.minimumWidth: 160
        Layout.minimumHeight: 160

        readonly property real _minSide: Math.min(width, height)
        readonly property real _btnSize: _minSide * 0.22

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
            realtimeRefraction: plasmoid.configuration.realtimeRefraction
            fallbackOpacity: colors.glassFallbackOpacity
            solidMode: colors.isSolid
            solidColor: colors.solidBackground
        }

        // ── Picker (IDLE) ─────────────────────────────────────────────────
        Item {
            id: pickerArea
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                bottom: buttonRow.top
            }
            visible: root.timerState === 0
            opacity: root.timerState === 0 ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Row {
                anchors.centerIn: parent
                // Extra right spacing to account for the label text overflowing picker bounds
                spacing: full._minSide * 0.12

                CylinderPicker {
                    id: minPicker
                    count: 100
                    currentIndex: root.selectedMinutes
                    label: "min"
                    fontFamily: sfThin.name
                    labelFontFamily: sfRegular.name
                    textColor: colors.foreground
                    separatorColor: colors.foreground
                    height: pickerArea.height * 0.86
                    width: full._minSide * 0.22
                    onCurrentIndexChanged: root.selectedMinutes = currentIndex
                }

                CylinderPicker {
                    id: secPicker
                    count: 60
                    currentIndex: root.selectedSeconds
                    label: "sec"
                    fontFamily: sfThin.name
                    labelFontFamily: sfRegular.name
                    textColor: colors.foreground
                    separatorColor: colors.foreground
                    height: pickerArea.height * 0.86
                    width: full._minSide * 0.22
                    onCurrentIndexChanged: root.selectedSeconds = currentIndex
                }
            }
        }

        // ── Countdown (RUNNING / PAUSED / FINISHED) ───────────────────────
        Item {
            id: countdownArea
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                bottom: buttonRow.top
            }
            visible: root.timerState !== 0
            opacity: root.timerState !== 0 ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            CountdownDisplay {
                anchors.centerIn: parent
                width: parent.width * 0.92
                height: parent.height * 0.75
                minutes: root.displayMinutes
                seconds: root.displaySeconds
                fontFamily: sfRegular.name
                textColor: "#FF8B00"
                digitOpacity: 1.0
                flashing: root.timerState === 3
            }
        }

        // ── Button row ─────────────────────────────────────────────────────
        Item {
            id: buttonRow
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                bottomMargin: full._minSide * 0.08
            }
            height: full._btnSize

            // Cancel — left half, visible when timer is active
            TimerButton {
                id: cancelBtn
                diameter: full._btnSize
                iconSource: Qt.resolvedUrl("widget/icons/cancel.svg")
                iconColor: "#ffffff"
                backgroundColor: Qt.rgba(1, 1, 1, 0.15)
                visible: root.timerState !== 0
                opacity: root.timerState !== 0 ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width / 4 - diameter / 2
                onClicked: root.cancelTimer()
            }

            // Action button — centered when IDLE, right quarter when active
            TimerButton {
                id: actionBtn
                diameter: full._btnSize

                iconSource: {
                    if (root.timerState === 1) return Qt.resolvedUrl("widget/icons/pause.svg")
                    if (root.timerState === 3) return Qt.resolvedUrl("widget/icons/reload.svg")
                    return Qt.resolvedUrl("widget/icons/play.svg")
                }

                iconColor: root.timerState === 1 ? "#FF8E00" : "#00D443"

                backgroundColor: {
                    if (root.timerState === 1)
                        return Qt.rgba(1, 0.557, 0, 0.18)
                    return Qt.rgba(0, 0.831, 0.263, 0.18)
                }

                Behavior on iconColor { ColorAnimation { duration: 180 } }
                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                x: root.timerState === 0
                    ? (parent.width - diameter) / 2
                    : parent.width * 3 / 4 - diameter / 2

                anchors.verticalCenter: parent.verticalCenter

                enabled: root.timerState !== 0 || (root.selectedMinutes > 0 || root.selectedSeconds > 0)
                opacity: enabled ? 1.0 : 0.35
                Behavior on opacity { NumberAnimation { duration: 150 } }

                onClicked: {
                    if (root.timerState === 0) root.startTimer()
                    else if (root.timerState === 1) root.pauseTimer()
                    else if (root.timerState === 2) root.resumeTimer()
                    else root.cancelTimer()
                }
            }
        }
    }
}
