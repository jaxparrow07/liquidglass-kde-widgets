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
    preferredRepresentation: (Plasmoid.formFactor === PlasmaCore.Types.Horizontal ||
                              Plasmoid.formFactor === PlasmaCore.Types.Vertical)
                             ? compactRepresentation : fullRepresentation

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
        interval: 1000
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
    compactRepresentation: Item {
        id: compact

        readonly property bool _isActive: root.timerState !== 0

        states: [
            State {
                name: "horizontalPanel"
                when: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
                PropertyChanges {
                    compact.Layout.fillHeight: true
                    compact.Layout.fillWidth: false
                    compact.Layout.minimumWidth: compactRow.implicitWidth + compact.height * 0.3
                    compact.Layout.maximumWidth: compact.Layout.minimumWidth
                }
            },
            State {
                name: "verticalPanel"
                when: Plasmoid.formFactor === PlasmaCore.Types.Vertical
                PropertyChanges {
                    compact.Layout.fillHeight: false
                    compact.Layout.fillWidth: true
                    compact.Layout.minimumHeight: compactRow.implicitHeight + compact.width * 0.3
                    compact.Layout.maximumHeight: compact.Layout.minimumHeight
                }
            },
            State {
                name: "desktop"
                when: Plasmoid.formFactor !== PlasmaCore.Types.Horizontal &&
                      Plasmoid.formFactor !== PlasmaCore.Types.Vertical
                PropertyChanges {
                    compact.Layout.minimumWidth: compactRow.implicitWidth + 8
                    compact.Layout.minimumHeight: compactRow.implicitHeight + 8
                }
            }
        ]

        SequentialAnimation on opacity {
            running: root.timerState === 3
            loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 500; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutQuad }
            onRunningChanged: if (!running) compact.opacity = 1.0
        }

        Row {
            id: compactRow
            anchors.centerIn: parent
            spacing: Math.round(compact.height * 0.18)

            Canvas {
                id: progressRing
                width: compact.height * 0.72
                height: compact.height * 0.72
                anchors.verticalCenter: parent.verticalCenter
                antialiasing: true

                property real _p: root.totalMs > 0
                    ? (root.totalMs - root.remainingMs) / root.totalMs : 0
                property int _state: root.timerState

                on_PChanged: requestPaint()
                on_StateChanged: requestPaint()
                Component.onCompleted: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()

                    var cx = width / 2
                    var cy = height / 2
                    var sw = Math.max(2, width * 0.10)
                    var r = cx - sw / 2 - 1

                    // Static ring — no fill effect, always full circle
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                    ctx.strokeStyle = "#FF8D00"
                    ctx.lineWidth = sw
                    ctx.stroke()

                    // Clock hand: from center, tip leaves a gap = sw from the ring inner edge
                    var handAngle = -Math.PI / 2 - _p * 2 * Math.PI
                    var handLen = r - sw - sw  // inner edge of ring minus one stroke width gap
                    var dx = Math.cos(handAngle)
                    var dy = Math.sin(handAngle)
                    ctx.beginPath()
                    ctx.moveTo(cx, cy)
                    ctx.lineTo(cx + dx * handLen, cy + dy * handLen)
                    ctx.strokeStyle = "#FF8D00"
                    ctx.lineWidth = sw
                    ctx.lineCap = "round"
                    ctx.stroke()
                }
            }

            Text {
                id: compactLabel
                anchors.verticalCenter: parent.verticalCenter
                width: compactLabelMetrics.width
                text: compact._isActive
                    ? (root.displayMinutes < 10 ? "0" + root.displayMinutes : "" + root.displayMinutes) + ":" +
                      (root.displaySeconds < 10 ? "0" + root.displaySeconds : "" + root.displaySeconds)
                    : "Timer"
                color: "#ffffff"
                font.family: sfRegular.name
                font.pixelSize: Math.round(compact.height * 0.36)
                horizontalAlignment: Text.AlignLeft

                TextMetrics {
                    id: compactLabelMetrics
                    font: compactLabel.font
                    text: "00:00"
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    ListModel {
        id: presetsModel
        ListElement { label: "1 min";  mins: 1;  secs: 0; pillColor: "#4ECDC4" }
        ListElement { label: "2 min";  mins: 2;  secs: 0; pillColor: "#45B7D1" }
        ListElement { label: "3 min";  mins: 3;  secs: 0; pillColor: "#96CEB4" }
        ListElement { label: "5 min";  mins: 5;  secs: 0; pillColor: "#FF6B6B" }
        ListElement { label: "10 min"; mins: 10; secs: 0; pillColor: "#DDA0DD" }
        ListElement { label: "15 min"; mins: 15; secs: 0; pillColor: "#FFB347" }
    }

    fullRepresentation: Item {
        id: full
        Layout.preferredWidth: 200
        Layout.preferredHeight: 200
        Layout.minimumWidth: 160
        Layout.minimumHeight: 160

        readonly property bool isWide: full.width >= full.height * 2
        readonly property real wideGap: Math.round(full.height * 0.04)
        readonly property real _minSide: Math.min(width, height)
        readonly property real _btnSize: _minSide * 0.22

        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: (Plasmoid.formFactor === PlasmaCore.Types.Horizontal ||
                     Plasmoid.formFactor === PlasmaCore.Types.Vertical)
                    ? Math.min(plasmoid.configuration.cornerRadius, 20)
                    : plasmoid.configuration.cornerRadius
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

        // ── Left panel: Presets (wide mode only) ──────────────────────────
        Item {
            id: leftPanel
            visible: full.isWide
            clip: true
            anchors {
                top: parent.top
                left: parent.left
                bottom: parent.bottom
                right: rightPanel.left
                rightMargin: full.wideGap
            }

            readonly property real _margin: Math.round(full.height * 0.09)
            readonly property real _cardSize: Math.max(10, Math.round(full.height * 0.052))
            readonly property real _cardSpacing: Math.round(full.height * 0.025)

            Text {
                id: presetsTitle
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: leftPanel._margin
                    leftMargin: leftPanel._margin
                }
                text: "Presets"
                color: colors.foreground
                font.family: sfRegular.name
                font.pixelSize: Math.max(10, Math.round(full.height * 0.058))
                font.weight: Font.Regular
                opacity: 0.55
                font.letterSpacing: 0.5
            }

            ListView {
                id: presetsList
                anchors {
                    top: presetsTitle.bottom
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    topMargin: leftPanel._cardSpacing
                    leftMargin: leftPanel._margin
                    rightMargin: leftPanel._margin
                    bottomMargin: leftPanel._margin
                }
                model: presetsModel
                spacing: leftPanel._cardSpacing
                clip: true

                delegate: PresetCard {
                    width: presetsList.width
                    label: model.label
                    pillColor: model.pillColor
                    textColor: colors.foreground
                    fontFamily: sfRegular.name
                    fontSize: leftPanel._cardSize
                    isGlass: colors.isGlass
                    isLight: colors.isLight
                    active: root.timerState === 0
                    onClicked: {
                        root.selectedMinutes = model.mins
                        root.selectedSeconds = model.secs
                        root.startTimer()
                    }
                }
            }

        }

        // ── Right panel: Timer content ────────────────────────────────────
        Item {
            id: rightPanel
            width: full.isWide ? full.height : full.width
            anchors {
                top: parent.top
                right: parent.right
                bottom: parent.bottom
            }
        }

        // ── Picker (IDLE) ─────────────────────────────────────────────────
        Item {
            id: pickerArea
            parent: rightPanel
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
                    fontFamily: sfRegular.name
                    labelFontFamily: sfRegular.name
                    textColor: colors.foreground
                    separatorColor: colors.foreground
                    fontWeight: Font.Medium
                    fontSizeScale: 0.82
                    height: pickerArea.height * 0.86
                    width: full._minSide * 0.22
                    onCurrentIndexChanged: root.selectedMinutes = currentIndex
                }

                CylinderPicker {
                    id: secPicker
                    count: 60
                    currentIndex: root.selectedSeconds
                    label: "sec"
                    fontFamily: sfRegular.name
                    labelFontFamily: sfRegular.name
                    textColor: colors.foreground
                    separatorColor: colors.foreground
                    fontWeight: Font.Medium
                    fontSizeScale: 0.82
                    height: pickerArea.height * 0.86
                    width: full._minSide * 0.22
                    onCurrentIndexChanged: root.selectedSeconds = currentIndex
                }
            }
        }

        // ── Countdown (RUNNING / PAUSED / FINISHED) ───────────────────────
        Item {
            id: countdownArea
            parent: rightPanel
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
                textColor: colors.isGlass ? "#ffffff" : "#FF8B00"
                digitOpacity: 1.0
                flashing: root.timerState === 3
            }
        }

        // ── Button row ─────────────────────────────────────────────────────
        Item {
            id: buttonRow
            parent: rightPanel
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
                iconColor: colors.isGlass ? "#ffffff" : colors.foreground
                backgroundColor: colors.isGlass
                    ? Qt.rgba(1, 1, 1, 0.25)
                    : Qt.rgba(colors.foreground.r, colors.foreground.g, colors.foreground.b, 0.12)
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

                iconColor: colors.isGlass ? "#ffffff" : (root.timerState === 1 ? "#FF8E00" : "#00A832")

                backgroundColor: {
                    if (colors.isGlass) {
                        if (root.timerState === 1) return "#FF8E00"
                        return "#00A832"
                    }
                    if (root.timerState === 1) return Qt.rgba(1, 0.557, 0, 0.18)
                    return Qt.rgba(0, 0.659, 0.196, 0.18)
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
