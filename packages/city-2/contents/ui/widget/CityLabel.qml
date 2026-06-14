import QtQuick

// City annotation block for the City widgets. Three modes:
//
//   "single"  — 1x1: the city CODE above center and the hour-diff below center,
//               sitting inside the dial (above/below the hour numerals). The
//               caller positions this item to fill the dial; we place the two
//               texts vertically offset from the vertical center by `inset`.
//   "code"    — 2x2 grid: just the city CODE, drawn as a single centered line
//               (the caller places it below the face).
//   "full"    — 4x2 row: NAME (primary), day word + offset (secondary), stacked.
//
// Colors/opacities are passed in; SF Pro Rounded font supplied by the caller.

Item {
    id: root

    property string mode: "single"

    property string code: ""
    property string name: ""
    property string dayWord: ""
    property string offsetLabel: ""

    property string fontFamily: ""
    property color  textColor: "#ffffff"
    property real   primaryOpacity: 1.0      // name (full) / code
    property real   secondaryOpacity: 0.85   // diff / day word
    property real   baseFontSize: 14

    // For "single": vertical distance of code/diff from center.
    property real centerInset: 0

    // --- single (1x1) ---
    Text {
        visible: root.mode === "single"
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height / 2 - root.centerInset - height / 2
        text: root.code
        font.family: root.fontFamily
        font.pixelSize: root.baseFontSize
        font.weight: Font.Medium
        color: root.textColor
        opacity: root.primaryOpacity
    }
    Text {
        visible: root.mode === "single"
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height / 2 + root.centerInset - height / 2
        text: root.offsetLabel
        font.family: root.fontFamily
        font.pixelSize: root.baseFontSize
        font.weight: Font.Medium
        color: root.textColor
        opacity: root.secondaryOpacity
    }

    // --- code (2x2) ---
    Text {
        visible: root.mode === "code"
        anchors.centerIn: parent
        text: root.code
        font.family: root.fontFamily
        font.pixelSize: root.baseFontSize
        font.weight: Font.Medium
        color: root.textColor
        opacity: root.primaryOpacity
        elide: Text.ElideRight
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
    }

    // Real height of the "full" stack, so callers can size/center a group to the
    // actual content instead of a guessed reservation.
    readonly property real fullContentHeight: fullColumn.implicitHeight

    // --- full (4x2) ---
    Column {
        id: fullColumn
        visible: root.mode === "full"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        spacing: Math.round(root.baseFontSize * 0.15)
        width: parent.width

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.name
            font.family: root.fontFamily
            font.pixelSize: root.baseFontSize
            font.weight: Font.Medium
            color: root.textColor
            opacity: root.primaryOpacity
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.dayWord
            font.family: root.fontFamily
            font.pixelSize: Math.round(root.baseFontSize * 0.85)
            font.weight: Font.Medium
            color: root.textColor
            opacity: root.secondaryOpacity
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.offsetLabel
            font.family: root.fontFamily
            font.pixelSize: Math.round(root.baseFontSize * 0.85)
            font.weight: Font.Medium
            color: root.textColor
            opacity: root.secondaryOpacity
        }
    }
}
