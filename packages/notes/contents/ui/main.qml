/*
    SPDX-FileCopyrightText: 2013 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2023 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2026 Thomas Eleveld <thomas.eleveld007@gmail.com>, inspiration taken from 2014 David Edmundson <davidedmundson@kde.org> and 2014, 2015 Kai Uwe Broulik <kde@privat.broulik.de>, with shaders by Jack Faith <zinczorphin@gmail.com>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents

import "components"

// Notes are array of html with typing (to-do / text)

PlasmoidItem {
    id: root

    readonly property int horizontalMargins: Math.round(width * 0.05)
    readonly property int verticalMargins: Math.round(height * 0.05)

    property Item activeField: null
    readonly property bool showTextDecorationButtons: activeField !== null

    Layout.minimumWidth: Kirigami.Units.gridUnit * 8
    Layout.minimumHeight: Kirigami.Units.gridUnit * 8

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    MacOSColors {
        id: colors
        styleMode: Plasmoid.configuration.styleMode
        appearance: Plasmoid.configuration.appearance
    }

    // Data
    ListModel { id: rows }

    // save data on debuffer and on out of focus
    Timer {
        id: saveTimer
        interval: 800
        onTriggered: root.saveNow()
    }

    function save() { saveTimer.restart(); }

    function saveNow() {
        const out = [];
        for (let i = 0; i < rows.count; i++) {
            const r = rows.get(i);
            out.push({ type: r.type, html: r.html, checked: r.checked });
        }
        Plasmoid.configuration.Rows = JSON.stringify(out);
    }

    Component.onCompleted: {
        let saved = [];
        try { saved = JSON.parse(Plasmoid.configuration.Rows); } catch (e) {}
        if (!Array.isArray(saved) || saved.length === 0) {
            // first run / seems to make row correctly but doesnt show (needs to be fixed!)
            saved = [{ type: "text", html: Plasmoid.configuration.Text || "", checked: false }];
        }
        saved.forEach(r => rows.append({
            type: r.type ?? "text",
            html: r.html ?? "",
            checked: !!r.checked
        }));
    }

    Component.onDestruction: saveNow()

    onExternalData: (mimetype, data) => {
        if (mimetype === "text/plain") {
            rows.append({ 
                type: "text", 
                html: data.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'), 
                checked: false 
            });
            save();
        }
    }

    // Row formatting
    function toggleFormat(prop) {
        const f = activeField;
        if (!f) return;
        const s = f.selectionStart, e = f.selectionEnd;
        f.cursorSelection.font[prop] = !f.cursorSelection.font[prop];
        if (s !== e) f.select(Math.min(s, e), Math.max(s, e));
    }

    function toggleType() {
        const f = activeField;
        if (!f) return;
        rows.setProperty(f.rowIndex, "type", f.isCheck ? "text" : "check");
        save();
        f.forceActiveFocus();
    }

    function applyColor(f, c) {
        if (!f) return;
        const s = f.selectionStart, e = f.selectionEnd;
        f.cursorSelection.color = c;
        if (s !== e) f.select(Math.min(s, e), Math.max(s, e));
        f.forceActiveFocus();
    }

    // UI
    fullRepresentation: Item {
        id: fullRepContainer

        // helper functions
        function focusRow(i, atEnd) {
            Qt.callLater(() => {
                list.positionViewAtIndex(i, ListView.Contain);
                const item = list.itemAtIndex(i);
                if (item) item.focusField(atEnd);
            });
        }

        function insertRow(at, type, html) {
            rows.insert(at, { type: type, html: html ?? "", checked: false });
            root.save();
            focusRow(at, false);
        }

        function removeRow(i) {
            rows.remove(i);
            root.save();
            focusRow(i > 0 ? i - 1 : 0, i > 0);
        }

        LiquidGlass {
            id: glass
            anchors.fill: parent

            radius: Plasmoid.configuration.cornerRadius
            roundness: Plasmoid.configuration.roundnessX10 / 10
            refractThickness: Plasmoid.configuration.refractThickness
            refractIOR: Plasmoid.configuration.refractIORx100 / 100
            refractScale: Plasmoid.configuration.refractScale
            tint: colors.glassTint
            tintAlpha: Plasmoid.configuration.tintAlphaPct / 100
            chromaStrength: Plasmoid.configuration.chromaStrengthPct / 100
            specStrength: Plasmoid.configuration.specStrengthPct / 100
            blurRadius: Plasmoid.configuration.blurRadiusPx
            realtimeRefraction: Plasmoid.configuration.realtimeRefraction
            fallbackOpacity: colors.glassFallbackOpacity
            solidMode: colors.isSolid && Plasmoid.configuration.opaqueBackground
            solidColor: "#1A1B1E"
        }

        ColumnLayout {
            anchors {
                fill: parent
                leftMargin: root.horizontalMargins
                rightMargin: root.horizontalMargins
                topMargin: root.verticalMargins
                bottomMargin: root.verticalMargins
            }
            spacing: Kirigami.Units.smallSpacing

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: rows
                spacing: 2
                topMargin: 2
                bottomMargin: 2
                clip: true

                PlasmaComponents.ScrollBar.vertical: PlasmaComponents.ScrollBar {}

                // clicking empty space focuses the last row
                footer: MouseArea {
                    width: list.width
                    height: Kirigami.Units.gridUnit * 10
                    onClicked: fullRepContainer.focusRow(rows.count - 1, true)
                }

                delegate: RowLayout {
                    id: row
                    width: ListView.view.width

                    function focusField(atEnd) {
                        field.forceActiveFocus();
                        field.cursorPosition = atEnd ? field.length : 0;
                    }

                    function appendHtml(html) {
                        const joinPos = field.length;
                        field.insert(joinPos, html);
                        return joinPos;
                    }

                    function focusAt(pos) {
                        field.forceActiveFocus();
                        field.cursorPosition = pos;
                    }

                    PlasmaComponents.CheckBox {
                        id: box
                        Layout.alignment: Qt.AlignTop
                        visible: model.type === "check"
                        focusPolicy: Qt.NoFocus
                        checked: model.checked
                        padding: 0
                        
                        Layout.leftMargin: Kirigami.Units.smallSpacing
                        Layout.topMargin: field.topPadding + Math.max(0, (field.positionToRectangle(0).height - implicitHeight) / 2)

                        onToggled: {
                            rows.setProperty(index, "checked", checked);
                            root.save();
                        }

                        // checkmark is transparent in white parent
                        indicator: Item {
                            id: ind
                            implicitWidth: Kirigami.Units.gridUnit * 1.2
                            implicitHeight: implicitWidth
                            x: box.leftPadding
                            y: box.topPadding

                            Rectangle {
                                id: disc
                                anchors.fill: parent
                                radius: 7
                                color: box.checked ? "white" : "transparent"
                                border.width: 1.5
                                border.color: "white"
                                opacity: box.checked ? 0 : 1
                            }

                            Item {
                                id: checkShape
                                anchors.fill: parent
                                visible: false
                                layer.enabled: true

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: "black"
                                    font.pixelSize: parent.height * 0.7
                                    font.bold: true
                                    scale: box.checked ? 1 : 0.4
                                    Behavior on scale { NumberAnimation { duration: 120 } }
                                }
                            }

                            MultiEffect {
                                anchors.fill: disc
                                source: disc
                                maskEnabled: true
                                maskSource: checkShape
                                maskInverted: true
                                opacity: box.checked ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 90 } }
                            }
                        }
                    }

                    PlasmaComponents.TextArea {
                        id: field
                        Layout.fillWidth: true
                        topPadding: 0
                        bottomPadding: 0

                        readonly property int rowIndex: index
                        readonly property bool isCheck: model.type === "check"
                        property bool loaded: false

                        background: null
                        color: "white"
                        font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 1.2)
                        opacity: isCheck && model.checked ? 0.55 : 1
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.RichText

                        Component.onCompleted: {
                            text = model.html;
                            loaded = true;
                        }

                        onTextChanged: {
                            if (!loaded) return;
                            rows.setProperty(index, "html", text);
                            root.save();
                        }

                        onActiveFocusChanged: {
                            if (activeFocus) root.activeField = field;
                            else if (root.activeField === field){
                                root.activeField = null;
                                root.saveNow();
                            }
                        }

                        // all keyboard events, including shortcuts and navigation through rows
                        Keys.onPressed: (event) => {
                            const ctrl = event.modifiers & Qt.ControlModifier;
                            const shift = event.modifiers & Qt.ShiftModifier;

                            if (ctrl) {
                                if (!shift && event.key === Qt.Key_B) root.toggleFormat("bold");
                                else if (!shift && event.key === Qt.Key_I) root.toggleFormat("italic");
                                else if (!shift && event.key === Qt.Key_U) root.toggleFormat("underline");
                                else if (shift && event.key === Qt.Key_S) root.toggleFormat("strikeout");
                                else return;
                                event.accepted = true;
                                return;
                            }

                            // enter to split row
                            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !shift) {
                                if (isCheck && length === 0) {
                                    // enter on empty todo/check returns an empty row
                                    rows.setProperty(index, "type", "text");
                                    root.save();
                                } else {
                                    const pos = cursorPosition;
                                    const tail = pos < length ? getFormattedText(pos, length) : "";
                                    if (tail) remove(pos, length);
                                    fullRepContainer.insertRow(index + 1, model.type, tail);
                                }
                                event.accepted = true;

                            // backspace to remove row
                            } else if (event.key === Qt.Key_Backspace && cursorPosition === 0 && selectionStart === selectionEnd) {
                                if (isCheck) {
                                    rows.setProperty(index, "itemType", "text");
                                    root.save();
                                    event.accepted = true;
                                } else if (index > 0) {
                                    if (length === 0) {
                                        fullRepContainer.removeRow(index);
                                    } else {
                                        const tail = getFormattedText(0, length);
                                        const prev = list.itemAtIndex(index - 1);
                                        if (prev) {
                                            const joinPos = prev.appendHtml(tail);
                                            rows.remove(index);
                                            root.save();
                                            Qt.callLater(() => prev.focusAt(joinPos));
                                        }
                                    }
                                    event.accepted = true;
                                }

                            // Arrow keys hop between rows at the first/last visual line
                            } else if (event.key === Qt.Key_Up && !shift && index > 0 && Math.abs(positionToRectangle(0).y - cursorRectangle.y) < 1) {
                                fullRepContainer.focusRow(index - 1, true);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down && !shift && index < rows.count - 1 && Math.abs(positionToRectangle(length).y - cursorRectangle.y) < 1) {
                                fullRepContainer.focusRow(index + 1, false);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Left && cursorPosition === 0 && !shift && index > 0 ) {
                                fullRepContainer.focusRow(index - 1, false);
                                event.accepted = true;
                            }
                        }
                    }
                }
            }

            RowLayout {
                id: textDecorationToolbar
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                visible: root.showTextDecorationButtons

                Repeater {
                    model: [
                        { icon: "format-text-bold",          prop: "bold" },
                        { icon: "format-text-italic",        prop: "italic" },
                        { icon: "format-text-underline",     prop: "underline" },
                        { icon: "format-text-strikethrough", prop: "strikeout" }
                    ]

                    PlasmaComponents.ToolButton {
                        required property var modelData
                        icon.name: modelData.icon
                        focusPolicy: Qt.NoFocus
                        checkable: true
                        checked: root.activeField
                                 ? root.activeField.cursorSelection.font[modelData.prop]
                                 : false
                        onClicked: {
                            root.toggleFormat(modelData.prop);
                            if (root.activeField) root.activeField.forceActiveFocus();
                        }
                    }
                }

                PlasmaComponents.ToolButton {
                    icon.name: "checkbox"
                    focusPolicy: Qt.NoFocus
                    checkable: true
                    checked: root.activeField ? root.activeField.isCheck : false
                    onClicked: root.toggleType()
                }

                PlasmaComponents.ToolButton {
                    id: colorButton
                    icon.name: "format-text-color"
                    focusPolicy: Qt.NoFocus
                    onClicked: {
                        colorPopup.target = root.activeField;   // remember the row now
                        colorPopup.open();
                    }

                    Popup {
                        id: colorPopup
                        property Item target: null
                        y: -height - Kirigami.Units.smallSpacing
                        padding: Kirigami.Units.smallSpacing
                        focus: false
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                        readonly property var swatches: [
                            "#FFFFFF", "#FF453A", "#FF9F0A", "#FFD60A",
                            "#32D74B", "#64D2FF", "#0A84FF", "#BF5AF2"
                        ]

                        contentItem: Row {
                            spacing: Kirigami.Units.smallSpacing
                            Repeater {
                                model: colorPopup.swatches
                                Rectangle {
                                    required property string modelData
                                    width: Kirigami.Units.gridUnit * 1.3
                                    height: width
                                    radius: width / 2
                                    color: modelData
                                    border.width: 1
                                    border.color: Qt.alpha("white", 0.4)
                                    TapHandler {
                                        onTapped: {
                                            root.applyColor(colorPopup.target, parent.modelData);
                                            colorPopup.close();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}