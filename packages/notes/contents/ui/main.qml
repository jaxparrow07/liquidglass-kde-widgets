/*
    SPDX-FileCopyrightText: 2013 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2023 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2026 Thomas Eleveld <thomas.eleveld007@gmail.com>, inspiration taken from 2014 David Edmundson <davidedmundson@kde.org> and 2014, 2015 Kai Uwe Broulik <kde@privat.broulik.de>, with shaders by Jack Faith <zinczorphin@gmail.com>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents

import "components"

PlasmoidItem {
    id: root

    readonly property int horizontalMargins: Math.round(width * 0.05)
    readonly property int verticalMargins: Math.round(height * 0.05)

    property bool showTextDecorationButtons: false

    Layout.minimumWidth: Kirigami.Units.gridUnit * 8
    Layout.minimumHeight: Kirigami.Units.gridUnit * 8

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    MacOSColors {
        id: colors
        styleMode: Plasmoid.configuration.styleMode
        appearance: Plasmoid.configuration.appearance
    }

    onExternalData: (mimetype, data) => {
        if (mimetype === "text/plain") {
            noteText.text = data;
        }
    }

    fullRepresentation: Item {
        id: fullRepContainer

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

            PlasmaComponents.ScrollView {
                id: scrollview
                Layout.fillWidth: true
                Layout.fillHeight: true

                PlasmaComponents.ScrollBar.horizontal.policy: PlasmaComponents.ScrollBar.AlwaysOff

                PlasmaComponents.TextArea {
                    id: noteText
                    width: scrollview.availableWidth

                    background: null
                    color: Qt.alpha("white", 1)
                    font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 1.2)
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.RichText

                    text: Plasmoid.configuration.Text
                    onEditingFinished: {
                        Plasmoid.configuration.Text = text;
                    }

                    onActiveFocusChanged: {
                        showTextDecorationButtons = activeFocus;
                    }

                    Keys.onPressed: (event) => {
                        const isCtrl = event.modifiers & Qt.ControlModifier;
                        const isShift = event.modifiers & Qt.ShiftModifier;

                        if (!isCtrl) return;

                        // Helper function to normalize selection direction to correctly apply text decoration
                        function toggleFormat(prop) {
                            let rawStart = noteText.selectionStart;
                            let rawEnd = noteText.selectionEnd;
                            let start = Math.min(rawStart, rawEnd);
                            let end = Math.max(rawStart, rawEnd);

                            noteText.cursorSelection.font[prop] = !noteText.cursorSelection.font[prop];

                            if (rawStart !== rawEnd) {
                                noteText.select(Math.min(rawStart, rawEnd), Math.max(rawStart, rawEnd));
                            }
                        }

                        // Shortcuts
                        if (!isShift && event.key === Qt.Key_B) {
                            toggleFormat("bold");
                            event.accepted = true;
                        } else if (!isShift && event.key === Qt.Key_I) {
                            toggleFormat("italic");
                            event.accepted = true;
                        } else if (!isShift && event.key === Qt.Key_U) {
                            toggleFormat("underline");
                            event.accepted = true;
                        } else if (isShift && event.key === Qt.Key_S) {
                            toggleFormat("strikeout");
                            event.accepted = true;
                        }
                    }
                }
            }

            RowLayout {
                id: textDecorationToolbar
                width: scrollview.availableWidth
                spacing: Kirigami.Units.smallSpacing
                visible: showTextDecorationButtons

                PlasmaComponents.ToolButton {
                    id: boldButton
                    icon.name: "format-text-bold"
                    focusPolicy: Qt.NoFocus
                    checkable: true
                    checked: noteText.cursorSelection.font.bold

                    onClicked: {
                        noteText.cursorSelection.font.bold = !noteText.cursorSelection.font.bold;
                        noteText.forceActiveFocus();
                    }
                }

                PlasmaComponents.ToolButton {
                    id: italicButton
                    icon.name: "format-text-italic"
                    focusPolicy: Qt.NoFocus
                    checkable: true
                    checked: noteText.cursorSelection.font.italic

                    onClicked: {
                        noteText.cursorSelection.font.italic = !noteText.cursorSelection.font.italic;
                        noteText.forceActiveFocus();
                    }
                }

                PlasmaComponents.ToolButton {
                    id: underlineButton
                    icon.name: "format-text-underline"
                    focusPolicy: Qt.NoFocus
                    checkable: true
                    checked: noteText.cursorSelection.font.underline

                    onClicked: {
                        noteText.cursorSelection.font.underline = !noteText.cursorSelection.font.underline;
                        noteText.forceActiveFocus();
                    }
                }

                PlasmaComponents.ToolButton {
                    id: strikeButton
                    icon.name: "format-text-strikethrough"
                    focusPolicy: Qt.NoFocus
                    checkable: true
                    checked: noteText.cursorSelection.font.strikeout

                    onClicked: {
                        noteText.cursorSelection.font.strikeout = !noteText.cursorSelection.font.strikeout;
                        noteText.forceActiveFocus();
                    }
                }
            }
        }
    }
}
