// BrightnessPopup — native brightness popup, styled exactly like VolumePopup (simpler).
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: window
    focus: true

    // props injected by Main.qml/executeSwitch — must be declared or injection errors/crashes
    property var notifModel
    property var liveNotifs
    property int layoutWidth
    property int layoutHeight

    Scaler {
        id: scaler
        currentWidth: Screen.width
    }
    function s(val) { return scaler.s(val) }

    MatugenColors { id: _theme }
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color mauve: _theme.mauve
    readonly property color peach: _theme.peach

    // brightness accent — reuses the volume "tabColor" notion
    readonly property color tabColor: window.mauve

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: true
    }

    // intro
    property real introMain: 0
    property real introHeader: 0
    SequentialAnimation on introMain {
        running: true
        NumberAnimation { from: 0; to: 1.0; duration: 800; easing.type: Easing.OutExpo }
    }
    SequentialAnimation on introHeader {
        running: true
        PauseAnimation { duration: 120 }
        NumberAnimation { from: 0; to: 1.0; duration: 700; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
    }

    // ---- brightness state ----
    property int brightness: 50
    property bool draggingMaster: false

    function readBrightness(): void {
        reader.running = false;
        reader.running = true;
    }
    Process {
        id: reader
        command: ["bash", "-c",
            "ddcutil --disable-flock getvcp 10 --brief --display 1 2>/dev/null | awk '/VCP/{print $4}' || echo 50"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    let v = parseInt(txt);
                    if (!isNaN(v)) window.brightness = Math.max(0, Math.min(100, v));
                }
            }
        }
    }

    Timer {
        id: setThrottle; interval: 60; property int target: -1
        onTriggered: {
            if (target >= 0) {
                Quickshell.execDetached(["bash", "-c",
                    "ddcutil --disable-flock setvcp 10 " + target + " --display 1 >/dev/null 2>&1"]);
                target = -1;
            }
        }
    }
    function setBrightness(v): void {
        window.brightness = Math.max(0, Math.min(100, v));
        setThrottle.target = window.brightness; setThrottle.restart();
    }

    Component.onCompleted: readBrightness()

    // ---------------------------------------------------------------------
    // THEME CHROME (mirrors VolumePopup)
    // ---------------------------------------------------------------------
    width: s(450)
    implicitHeight: s(300)

    Item {
        anchors.fill: parent
        scale: 0.95 + (0.05 * introMain)
        opacity: introMain

        Rectangle {
            anchors.fill: parent
            radius: window.s(20)
            color: window.base
            border.color: window.surface0
            border.width: 1
            clip: true

            // Rotating background blobs
            Rectangle {
                width: parent.width * 0.8; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.cos(window.globalOrbitAngle * 2) * window.s(150)
                y: (parent.height / 2 - height / 2) + Math.sin(window.globalOrbitAngle * 2) * window.s(100)
                opacity: 0.06; color: window.tabColor
            }
            Rectangle {
                width: parent.width * 0.9; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.sin(window.globalOrbitAngle * 1.5) * window.s(-150)
                y: (parent.height / 2 - height / 2) + Math.cos(window.globalOrbitAngle * 1.5) * window.s(-100)
                opacity: 0.04; color: Qt.lighter(window.tabColor, 1.3)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: window.s(25)
                spacing: window.s(20)

                // HERO ORB + MASTER SLIDER
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.s(150)
                    opacity: introHeader

                    RowLayout {
                        anchors.fill: parent
                        spacing: window.s(25)

                        // Orb
                        Item {
                            Layout.preferredWidth: window.s(130)
                            Layout.preferredHeight: window.s(130)
                            scale: orbMa.pressed ? 0.95 : (orbMa.containsMouse ? 1.05 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }

                            // pulse ring
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width + window.s(40); height: width; radius: width/2
                                color: window.tabColor; opacity: 0.15; z: -1
                                SequentialAnimation on scale {
                                    loops: Animation.Infinite; running: true
                                    NumberAnimation { to: orbMa.containsMouse ? 1.15 : 1.1; duration: orbMa.containsMouse ? 800 : 2000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: orbMa.containsMouse ? 800 : 2000; easing.type: Easing.InOutSine }
                                }
                            }
                            // core
                            Rectangle {
                                id: brightCore
                                anchors.fill: parent
                                radius: width / 2
                                color: window.base
                                border.color: Qt.lighter(window.tabColor, 1.1)
                                border.width: window.s(3)
                                clip: true
                                Text {
                                    anchors.centerIn: parent
                                    text: "☀️"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: window.s(46)
                                    color: window.peach
                                }
                            }
                            MouseArea {
                                id: orbMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: { window.brightness = window.brightness >= 95 ? 0 : 100 }
                            }
                        }

                        // Master slider column
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: window.s(14)

                            // value label
                            Text {
                                Layout.fillWidth: true
                                text: window.brightness + "%"
                                font.family: "JetBrains Mono"
                                font.pixelSize: window.s(46)
                                font.weight: Font.Black
                                color: window.text
                                horizontalAlignment: Text.AlignHCenter
                            }

                            // slider
                            Item {
                                Layout.fillWidth: true
                                height: window.s(26)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: window.s(13)
                                    color: "#0dffffff"; border.color: "#1affffff"; border.width: 1
                                    clip: true
                                    Rectangle {
                                        height: parent.height
                                        width: parent.width * (window.brightness / 100)
                                        radius: window.s(13)
                                        opacity: brightMa.containsMouse ? 1.0 : 0.85
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                        Behavior on width { enabled: !window.draggingMaster; NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: window.tabColor }
                                            GradientStop { position: 1.0; color: Qt.lighter(window.tabColor, 1.25) }
                                        }
                                    }
                                }
                                MouseArea {
                                    id: brightMa
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onPressed: (mouse) => { window.draggingMaster = true; setFromX(mouse.x) }
                                    onPositionChanged: (mouse) => { if (pressed) setFromX(mouse.x) }
                                    onReleased: { window.draggingMaster = false; setThrottle.stop(); Quickshell.execDetached(["bash", "-c", "ddcutil --disable-flock setvcp 10 " + window.brightness + " --display 1 >/dev/null 2>&1"]) }
                                    function setFromX(mx) {
                                        let pct = Math.max(0, Math.min(100, Math.round((mx / width) * 100)));
                                        window.setBrightness(pct);
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