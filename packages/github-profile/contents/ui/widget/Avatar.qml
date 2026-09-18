import QtQuick
import QtQuick.Effects

// Circular GitHub avatar with a monogram fallback shown while the image
// loads or if it fails. The circular crop uses a MultiEffect opacity mask,
// the same approach the shared About page uses for its promo card.
Item {
    id: avatar

    property string source: ""
    property string fallbackText: ""
    property color textColor: "#ffffff"
    property color borderColor: "#ffffff"
    property string fontFamily: ""

    // Invisible circular mask; only its alpha channel is used by MultiEffect.
    // layer.enabled keeps the hidden item rendered into a texture so it can
    // still serve as a maskSource (same trick as the About page promo card).
    Item {
        id: mask
        anchors.fill: parent
        layer.enabled: true
        visible: false
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "white"
        }
    }

    Image {
        id: img
        anchors.fill: parent
        source: avatar.source
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
        cache: true
        visible: status === Image.Ready
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
        }
    }

    // Monogram fallback (while loading or when the avatar fails to load).
    Rectangle {
        id: fallback
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: avatar.borderColor
        visible: img.status !== Image.Ready

        Text {
            anchors.centerIn: parent
            text: avatar.fallbackText
            color: avatar.textColor
            font.family: avatar.fontFamily
            font.pixelSize: Math.round(parent.height * 0.40)
            font.weight: Font.Medium
        }
    }
}
