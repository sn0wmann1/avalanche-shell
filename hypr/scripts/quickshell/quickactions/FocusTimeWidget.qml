import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root
    Caching { id: paths }

    property string safeActiveEdge: typeof activeEdge !== "undefined" ? activeEdge : "right"
    function s(val) { return typeof scaleFunc === "function" ? scaleFunc(val) : val; }

    readonly property color cBase: typeof mochaColors !== "undefined" && mochaColors ? mochaColors.base : "#1e1e2e"
    readonly property color cSurface0: typeof mochaColors !== "undefined" && mochaColors ? mochaColors.surface0 : "#313244"
    readonly property color cText: typeof mochaColors !== "undefined" && mochaColors ? mochaColors.text : "#cdd6f4"
    readonly property color cSubtext0: typeof mochaColors !== "undefined" && mochaColors ? mochaColors.subtext0 : "#a6adc8"
    readonly property color cMauve: typeof mochaColors !== "undefined" && mochaColors ? mochaColors.mauve : "#cba6f7"
    readonly property color cPeach: typeof mochaColors !== "undefined" && mochaColors ? mochaColors.peach : "#fab387"
    readonly property color cGreen: typeof mochaColors !== "undefined" && mochaColors ? mochaColors.green : "#a6e3a1"

    property string focusTimeStr: "--"
    property string currentApp: "--"
    property string currentAppIcon: ""
    property var topApps: []

    Timer {
        interval: 30000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { focusProc.running = false; focusProc.running = true }
    }
    Process {
        id: focusProc
        command: ["python3", "-c", "import json;d=json.load(open('/run/user/1000/quickshell/focustime/focustime_state.json'));s=d.get('total',0) or 0;h,s=divmod(int(s),3600);m,_=divmod(s,60);print(f'{h:02d}:{m:02d}' if h else f'{m:02d}m')"]
        stdout: StdioCollector {
            onStreamFinished: { root.focusTimeStr = this.text.trim() || "--"; }
        }
    }
    Process {
        id: currentProc
        command: ["python3", "-c", "import json;d=json.load(open('/run/user/1000/quickshell/focustime/focustime_state.json'));print(d.get('current','--'))"]
        stdout: StdioCollector {
            onStreamFinished: { root.currentApp = this.text.trim() || "--"; }
        }
    }
    Process {
        id: topProc
        command: ["python3", "-c", "import json;d=json.load(open('/run/user/1000/quickshell/focustime/focustime_state.json'));apps=d.get('apps',[]); [print(f\"{a.get('name','?')}|{a.get('seconds',0)}|{a.get('icon','')}\") for a in apps[:4]]"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = (this.text || "").trim().split("\n").filter(l => l);
                root.topApps = lines.map(l => { let p=l.split("|"); return {name:p[0]||"?",seconds:parseInt(p[1]||"0"),icon:p[2]||""}; });
            }
        }
    }

    Component.onCompleted: { currentProc.running=false; currentProc.running=true; topProc.running=false; topProc.running=true; }
    Timer { interval: 15000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { currentProc.running = false; currentProc.running = true; topProc.running = false; topProc.running = true } }

    Rectangle {
        anchors.fill: parent
        radius: root.s(16)
        color: root.cBase
        border.color: root.alpha(root.cText, 0.08)
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(16)
            spacing: root.s(12)

            RowLayout {
                spacing: root.s(10)
                Text { text: "󰄉"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(22); color: root.cMauve }
                Text { text: "Focus Time"; font.family: "JetBrains Mono"; font.pixelSize: root.s(16); font.weight: Font.Black; color: root.cText }
                Text { text: root.focusTimeStr; font.family: "JetBrains Mono"; font.pixelSize: root.s(16); font.weight: Font.Black; color: root.cPeach; Layout.alignment: Qt.AlignRight }
            }

            Rectangle { height: 1; color: root.alpha(root.cText, 0.08); Layout.fillWidth: true }

            RowLayout {
                spacing: root.s(8)
                Text { text: "Now"; font.family: "JetBrains Mono"; font.pixelSize: root.s(12); color: root.cSubtext0; width: root.s(48) }
                Text { text: root.currentApp; font.family: "JetBrains Mono"; font.pixelSize: root.s(12); color: root.cText; elide: Text.ElideRight }
            }

            Repeater {
                model: root.topApps
                delegate: RowLayout {
                    spacing: root.s(8)
                    Text { text: model.icon; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(14); color: root.cSubtext0; width: root.s(20) }
                    Text { text: model.name; font.family: "JetBrains Mono"; font.pixelSize: root.s(12); color: root.cText; elide: Text.ElideRight }
                    Text { text: root.fmtSec(model.seconds); font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.cSubtext0; Layout.alignment: Qt.AlignRight }
                }
            }

            Item { Layout.fillHeight: true }

            Text {
                text: "Open full dashboard →"
                font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.cMauve
                Layout.alignment: Qt.AlignRight
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle focustime"])
                    onEntered: parent.color = root.cPeach
                    onExited: parent.color = root.cMauve
                }
            }
        }
    }

    function alpha(color, a) { return Qt.rgba(color.r, color.g, color.b, a); }
    function fmtSec(totalSeconds) {
        let s = Math.max(0, Math.round(totalSeconds));
        let m = Math.floor(s / 60);
        if (m >= 60) {
            let h = Math.floor(m / 60);
            let rem = m % 60;
            return h + "h" + (rem ? rem + "m" : "");
        }
        return m + "m";
    }
}
