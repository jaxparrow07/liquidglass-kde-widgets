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
        weatherGradientCategory: weatherData.gradientCategory
    }

    FontLoader { id: sfLight;   source: Qt.resolvedUrl("../fonts/SF-Pro-Display-Light.otf") }
    FontLoader { id: sfRegular; source: Qt.resolvedUrl("../fonts/sf_pro_display_regular.otf") }

    WeatherData {
        id: weatherData
        location: plasmoid.configuration.location
        configLatitude: plasmoid.configuration.latitude
        configLongitude: plasmoid.configuration.longitude
        temperatureUnit: plasmoid.configuration.temperatureUnit
    }

    fullRepresentation: Item {
        id: full

        Layout.preferredWidth:  full.width  > 0 ? full.width  : 200
        Layout.preferredHeight: full.height > 0 ? full.height : 200
        Layout.minimumWidth: 160
        Layout.minimumHeight: 160

        readonly property real _minSide: Math.min(width, height)
        readonly property bool isWide: width >= height * 2
        readonly property bool isSmall: !isWide && _minSide < 350
        readonly property bool isBig: !isSmall && !isWide

        readonly property real labelSize: Math.max(10, Math.round(Math.min(full.height, 350) * 0.065))
        readonly property real bigLabelSize: Math.max(10, Math.round(Math.min(Math.min(full.height, full.width / 2), 350) * 0.065))

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
            solidColor: colors.isSolid ? colors.weatherGradientTop : colors.solidBackground
            solidColorBottom: colors.isSolid ? colors.weatherGradientBottom : "transparent"
        }

        // ── Small Layout ─────────────────────────────────────────────
        Item {
            id: smallLayout
            visible: full.isSmall
            anchors.fill: parent
            anchors.margins: Math.round(full.height * 0.09)

            Row {
                id: smallCity
                anchors.top: parent.top
                anchors.left: parent.left
                spacing: Math.round(full.labelSize * 0.25)

                Text {
                    text: weatherData.cityName || weatherData.location
                    color: colors.weatherForeground
                    font.family: sfRegular.name
                    font.pixelSize: Math.round(full.labelSize * 1.1)
                    font.weight: Font.Medium
                }

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(full.labelSize * 0.85)
                    height: width
                    source: Qt.resolvedUrl("icons/location.png")
                    smooth: true
                    mipmap: true
                }
            }

            Text {
                id: smallTemp
                anchors.top: smallCity.bottom
                anchors.left: parent.left
                text: weatherData.currentTemp + "°"
                color: colors.weatherForeground
                font.family: sfLight.name
                font.pixelSize: full.labelSize * 4
                font.weight: Font.Thin
            }

            WeatherIcon {
                id: smallIcon
                anchors.top: parent.top
                anchors.right: parent.right
                iconName: weatherData.iconNameForCode(weatherData.weatherCode, weatherData.isNight)
                iconSet: colors.weatherIconSet
                iconSize: full.labelSize * 3
            }

            Column {
                id: smallHighLow
                anchors.top: smallIcon.bottom
                anchors.topMargin: Math.round(full.labelSize * 0.3)
                anchors.right: parent.right
                spacing: Math.round(full.labelSize * 0.15)

                Row {
                    spacing: Math.round(full.labelSize * 0.15)
                    Text {
                        text: "↑"
                        color: colors.weatherForeground
                        font.family: sfRegular.name
                        font.pixelSize: full.labelSize
                    }
                    Text {
                        text: weatherData.highTemp + "°"
                        color: colors.weatherForeground
                        font.family: sfRegular.name
                        font.pixelSize: full.labelSize
                        font.weight: Font.Regular
                    }
                }
                Row {
                    spacing: Math.round(full.labelSize * 0.15)
                    Text {
                        text: "↓"
                        color: colors.weatherForeground
                        opacity: 0.70
                        font.family: sfRegular.name
                        font.pixelSize: full.labelSize
                    }
                    Text {
                        text: weatherData.lowTemp + "°"
                        color: colors.weatherForeground
                        opacity: 0.70
                        font.family: sfRegular.name
                        font.pixelSize: full.labelSize
                        font.weight: Font.Regular
                    }
                }
            }

            Column {
                anchors.left: parent.left
                anchors.bottom: parent.bottom

                readonly property real _infoSize: Math.round(full.labelSize * 0.88)

                spacing: 0

                Text {
                    text: i18n("Precipitation")
                    color: colors.weatherForeground
                    font.family: sfRegular.name
                    font.pixelSize: parent._infoSize
                    font.weight: Font.Medium
                }
                Text {
                    text: weatherData.precipitationSummary
                    color: colors.weatherForeground
                    opacity: 0.55
                    font.family: sfRegular.name
                    font.pixelSize: parent._infoSize
                    font.weight: Font.Regular
                    visible: weatherData.precipitationSummary !== ""
                }

                Item { width: 1; height: Math.round(full.labelSize * 0.35) }

                Text {
                    text: i18n("Wind")
                    color: colors.weatherForeground
                    font.family: sfRegular.name
                    font.pixelSize: parent._infoSize
                    font.weight: Font.Medium
                }
                Text {
                    text: weatherData.windSpeed + " " + weatherData.windUnit + " " + weatherData.windDirection
                    color: colors.weatherForeground
                    opacity: 0.55
                    font.family: sfRegular.name
                    font.pixelSize: parent._infoSize
                    font.weight: Font.Regular
                }
            }
        }

        // ── Big Square Layout ────────────────────────────────────────
        Item {
            id: bigLayout
            visible: full.isBig
            anchors.fill: parent
            anchors.margins: Math.round(full.height * 0.06)

            readonly property real topSectionH: height * 0.30
            readonly property real hourlyH: height * 0.22
            readonly property real _sepSpacing: Math.round(height * 0.02)

            Item {
                id: bigTop
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: bigLayout.topSectionH

                Column {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    spacing: 0

                    Text {
                        text: weatherData.cityName || weatherData.location
                        color: colors.weatherForeground
                        font.family: sfRegular.name
                        font.pixelSize: Math.round(full.bigLabelSize * 1.15)
                        font.weight: Font.Medium
                    }

                    Text {
                        text: weatherData.currentTemp + "°"
                        color: colors.weatherForeground
                        font.family: sfLight.name
                        font.pixelSize: Math.round(full.bigLabelSize * 3.5)
                        font.weight: Font.Thin
                    }
                }

                Column {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: Math.round(full.bigLabelSize * 0.3)

                    WeatherIcon {
                        anchors.right: parent.right
                        iconName: weatherData.iconNameForCode(weatherData.weatherCode, weatherData.isNight)
                        iconSet: colors.weatherIconSet
                        iconSize: full.bigLabelSize * 3
                    }

                    Text {
                        anchors.right: parent.right
                        text: weatherData.condition
                        color: colors.weatherForeground
                        font.family: sfRegular.name
                        font.pixelSize: full.bigLabelSize
                        font.weight: Font.Medium
                    }

                    Text {
                        anchors.right: parent.right
                        text: "H:" + weatherData.highTemp + "°  L:" + weatherData.lowTemp + "°"
                        color: colors.weatherForeground
                        opacity: 0.70
                        font.family: sfRegular.name
                        font.pixelSize: full.bigLabelSize
                        font.weight: Font.Medium
                    }
                }
            }

            Rectangle {
                id: sep1
                anchors.top: bigTop.bottom
                anchors.topMargin: bigLayout._sepSpacing
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: colors.weatherSeparator
            }

            HourlyForecast {
                id: bigHourly
                anchors.top: sep1.bottom
                anchors.topMargin: bigLayout._sepSpacing
                anchors.left: parent.left
                anchors.right: parent.right
                height: bigLayout.hourlyH
                slots: weatherData.hourlySlots
                iconSet: colors.weatherIconSet
                textColor: colors.weatherForeground
                secondaryTextColor: colors.weatherForeground
                secondaryOpacity: 0.70
                fontFamily: sfRegular.name
                baseFontSize: full.bigLabelSize
            }

            Rectangle {
                id: sep2
                anchors.top: bigHourly.bottom
                anchors.topMargin: bigLayout._sepSpacing
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: colors.weatherSeparator
            }

            DailyForecast {
                anchors.top: sep2.bottom
                anchors.topMargin: bigLayout._sepSpacing
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                days: weatherData.dailyForecast
                overallLow: weatherData.overallLow
                overallHigh: weatherData.overallHigh
                iconSet: colors.weatherIconSet
                textColor: colors.weatherForeground
                secondaryColor: colors.weatherForeground
                secondaryOpacity: 0.70
                rangeBarBg: colors.weatherRangeBarBg
                rangeBarFill: colors.weatherRangeBarFill
                fontFamily: sfRegular.name
                fontSize: full.bigLabelSize
                iconNameForCode: function(code, night) { return weatherData.iconNameForCode(code, night) }
            }
        }

        // ── Wide Layout ──────────────────────────────────────────────
        Column {
            id: wideLayout
            visible: full.isWide
            anchors.fill: parent
            anchors.margins: Math.round(full.height * 0.09)
            spacing: 0

            Item {
                id: wideTop
                width: parent.width
                Layout.fillWidth: true
                height: parent.height * 0.50

                Column {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    spacing: 0

                    Text {
                        text: weatherData.cityName || weatherData.location
                        color: colors.weatherForeground
                        font.family: sfRegular.name
                        font.pixelSize: Math.round(full.labelSize * 1.15)
                        font.weight: Font.Medium
                    }

                    Text {
                        text: weatherData.currentTemp + "°"
                        color: colors.weatherForeground
                        font.family: sfLight.name
                        font.pixelSize: Math.round(full.labelSize * 3.5)
                        font.weight: Font.Thin
                    }
                }

                Column {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: Math.round(full.labelSize * 0.3)

                    WeatherIcon {
                        anchors.right: parent.right
                        iconName: weatherData.iconNameForCode(weatherData.weatherCode, weatherData.isNight)
                        iconSet: colors.weatherIconSet
                        iconSize: full.labelSize * 3
                    }

                    Text {
                        anchors.right: parent.right
                        text: weatherData.condition
                        color: colors.weatherForeground
                        font.family: sfRegular.name
                        font.pixelSize: full.labelSize
                        font.weight: Font.Medium
                    }

                    Text {
                        anchors.right: parent.right
                        text: "H:" + weatherData.highTemp + "°  L:" + weatherData.lowTemp + "°"
                        color: colors.weatherForeground
                        opacity: 0.70
                        font.family: sfRegular.name
                        font.pixelSize: full.labelSize
                        font.weight: Font.Medium
                    }
                }
            }

            HourlyForecast {
                width: parent.width
                height: parent.height - wideTop.height
                slots: weatherData.hourlySlots
                iconSet: colors.weatherIconSet
                textColor: colors.weatherForeground
                secondaryTextColor: colors.weatherForeground
                secondaryOpacity: 0.70
                fontFamily: sfRegular.name
                baseFontSize: full.labelSize
            }
        }

        MacSpinner {
            anchors.centerIn: parent
            width: Math.round(full._minSide * 0.14)
            height: width
            running: weatherData.isLoading && weatherData.currentTemp === "--"
            visible: running
            z: 5
        }

        MouseArea {
            anchors.fill: parent
            z: 10
            acceptedButtons: Qt.LeftButton
            propagateComposedEvents: true
            onClicked: {
                weatherData.forceRefresh()
                mouse.accepted = false
            }
        }
    }
}
