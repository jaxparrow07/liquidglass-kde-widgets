import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtCore
import Qt.labs.folderlistmodel
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import "components"
import "widget"

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    WidgetActions { id: commonActions }

    PlasmaCore.Action {
        id: nextAction
        text: i18n("Next Photo")
        icon.name: "go-next"
        enabled: root.photos.length > 1
        onTriggered: root.showNext()
    }

    PlasmaCore.Action {
        id: openAction
        text: i18n("Open in Gwenview")
        icon.name: "gwenview"
        enabled: root.currentPhoto !== ""
        onTriggered: root.openCurrent()
    }

    Plasmoid.contextualActions: [openAction, nextAction].concat(commonActions.list)
    preferredRepresentation: fullRepresentation

    MacOSColors {
        id: colors
        styleMode: plasmoid.configuration.styleMode
        autoStyle: plasmoid.configuration.autoStyle
        appearance: plasmoid.configuration.appearance
    }

    FontLoader { id: sfText; source: Qt.resolvedUrl("../fonts/sf_pro_display_regular.otf") }

    // ── Photo list ───────────────────────────────────────────────────────
    readonly property string folderPath: plasmoid.configuration.folder !== ""
        ? plasmoid.configuration.folder
        : StandardPaths.writableLocation(StandardPaths.PicturesLocation).toString().replace(/^file:\/\//, "")

    property var photos: []
    property int index: -1
    readonly property string currentPhoto: index >= 0 && index < photos.length ? photos[index] : ""

    FolderListModel {
        id: folderModel
        folder: "file://" + root.folderPath
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.bmp", "*.avif", "*.heic", "*.heif",
                      "*.JPG", "*.JPEG", "*.PNG", "*.WEBP", "*.GIF", "*.BMP", "*.AVIF", "*.HEIC", "*.HEIF"]
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name
        onStatusChanged: if (status === FolderListModel.Ready) root.rebuild()
        onCountChanged: if (status === FolderListModel.Ready) root.rebuild()
    }

    function rebuild() {
        var list = []
        for (var i = 0; i < folderModel.count; i++)
            list.push(folderModel.get(i, "filePath"))
        if (plasmoid.configuration.shuffle) {
            for (var j = list.length - 1; j > 0; j--) {
                var k = Math.floor(Math.random() * (j + 1))
                var t = list[j]; list[j] = list[k]; list[k] = t
            }
        }
        var keep = currentPhoto
        photos = list
        var at = list.indexOf(keep)
        index = at >= 0 ? at : (list.length > 0 ? 0 : -1)
    }

    function showNext() {
        if (photos.length === 0) return
        index = (index + 1) % photos.length
        cycleTimer.restart()
    }

    Connections {
        target: plasmoid.configuration
        function onShuffleChanged() { root.rebuild() }
    }

    Timer {
        id: cycleTimer
        interval: Math.max(1, plasmoid.configuration.intervalMinutes) * 60 * 1000
        repeat: true
        running: root.photos.length > 1
        onTriggered: root.showNext()
    }

    // ── Opening in Gwenview ──────────────────────────────────────────────
    P5Support.DataSource {
        id: launcher
        engine: "executable"
        onNewData: (source) => disconnectSource(source)
    }

    function openCurrent() {
        if (currentPhoto === "") return
        // Single-quoted for the shell; embedded quotes are closed and escaped.
        var quoted = "'" + currentPhoto.replace(/'/g, "'\\''") + "'"
        launcher.connectSource("gwenview " + quoted + " || xdg-open " + quoted)
    }

    fullRepresentation: Item {
        id: full

        Layout.preferredWidth:  full.width  > 0 ? full.width  : 336
        Layout.preferredHeight: full.height > 0 ? full.height : 160
        Layout.minimumWidth: 160
        Layout.minimumHeight: 160

        readonly property real labelSize: Math.max(10, Math.round(Math.min(full.height, 350) * 0.066))

        StyleFade { styleColors: colors; duration: plasmoid.configuration.styleFadeMs }

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
            blurAlgorithm: plasmoid.configuration.blurAlgorithm
            realtimeRefraction: plasmoid.configuration.realtimeRefraction
            fallbackOpacity: colors.glassFallbackOpacity
            solidMode: colors.isSolid
            solidColor: colors.photosSolidBackground
        }

        // ── Photo ───────────────────────────────────────────────────────
        // Two layers cross-fade: the incoming one fades in over the other.
        Item {
            id: photoSource
            anchors.fill: parent
            visible: false
            layer.enabled: true

            property bool frontIsA: true

            Image {
                id: imageA
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                autoTransform: true
                cache: false
                sourceSize.width: full.width * Screen.devicePixelRatio
                sourceSize.height: full.height * Screen.devicePixelRatio
                opacity: photoSource.frontIsA ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
            }
            Image {
                id: imageB
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                autoTransform: true
                cache: false
                sourceSize.width: full.width * Screen.devicePixelRatio
                sourceSize.height: full.height * Screen.devicePixelRatio
                opacity: photoSource.frontIsA ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
            }

            // Load the new photo into the hidden layer; swap once it's ready.
            function show(path) {
                var back = frontIsA ? imageB : imageA
                if (path === "") { imageA.source = ""; imageB.source = ""; return }
                back.source = "file://" + path
            }

            Connections {
                target: imageA
                function onStatusChanged() { if (imageA.status === Image.Ready && !photoSource.frontIsA) photoSource.frontIsA = true }
            }
            Connections {
                target: imageB
                function onStatusChanged() { if (imageB.status === Image.Ready && photoSource.frontIsA) photoSource.frontIsA = false }
            }
        }

        Connections {
            target: root
            function onCurrentPhotoChanged() { photoSource.show(root.currentPhoto) }
        }
        Component.onCompleted: photoSource.show(root.currentPhoto)

        SquircleMask {
            id: photoMask
            anchors.fill: parent
            cornerRadius: plasmoid.configuration.cornerRadius
            roundness: plasmoid.configuration.roundnessX10 / 10
        }

        MultiEffect {
            anchors.fill: parent
            source: photoSource
            maskEnabled: true
            maskSource: photoMask
            saturation: colors.photoSaturation
            opacity: colors.photoOpacity
            visible: root.currentPhoto !== ""
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        // ── Empty state (as on macOS Tahoe) ─────────────────────────────
        Column {
            anchors.centerIn: parent
            width: parent.width * 0.66
            spacing: Math.round(full.labelSize * 0.6)
            visible: root.currentPhoto === ""

            PhotosIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                styleColors: colors
                size: Math.round(Math.min(full.width, full.height) * 0.43)
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: colors.foreground
                opacity: colors.photosPlaceholderOpacity
                font.family: sfText.name
                font.weight: Font.Bold
                font.pixelSize: full.labelSize
                lineHeight: 0.95
                text: i18n("Photos will appear here when they are finished processing")
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: root.currentPhoto !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.openCurrent()
        }
    }
}
