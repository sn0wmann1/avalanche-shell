import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: window
    property var prayerTimes: []
    property string nextPrayer: ""
    property string nextPrayerTime: ""
    property string nextPrayerCountdown: ""
    property var erbilPrayerTimes: ({})
    
    function loadErbilPrayerTimes(): void {
        const path = Quickshell.env("HOME") + "/Dotfiles/quickshell/caelestia/assets/prayer-times/erbil.json";
        const file = new XMLHttpRequest();
        file.open("GET", path, false);
        file.send();
        if (file.status === 200) {
            try {
                const data = JSON.parse(file.responseText);
                erbilPrayerTimes = {};
                for (let i = 0; i < data.length; i++) {
                    const entry = data[i];
                    erbilPrayerTimes[entry.date] = entry;
                }
            } catch(e) {
                console.warn("Failed to load prayer times:", e);
            }
        }
    }
    
    function updatePrayerTimes(): void {
        const now = new Date();
        const mmdd = `${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
        
        let timings = null;
        if (erbilPrayerTimes[mmdd]) {
            timings = erbilPrayerTimes[mmdd];
        }
        
        if (!timings) {
            prayerTimes = [];
            nextPrayer = "";
            nextPrayerTime = "";
            nextPrayerCountdown = "";
            return;
        }
        
        const names = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];
        const list = [];
        
        for (const name of names) {
            const hm = (timings[name] || timings[name.toLowerCase()] || "").split(":").map(Number);
            if (hm.length < 2 || isNaN(hm[0]) || isNaN(hm[1]))
                continue;
            
            const t = new Date(now);
            t.setHours(hm[0], hm[1], 0, 0);
            
            if (t < now)
                t.setDate(t.getDate() + 1);
            
            list.push({
                name: name,
                time: t,
                timeStr: `${String(hm[0]).padStart(2, "0")}:${String(hm[1]).padStart(2, "0")}`
            });
        }
        
        list.sort((a, b) => a.time - b.time);
        prayerTimes = list;
        
        for (let i = 0; i < list.length; i++) {
            if (list[i].time > now) {
                nextPrayer = list[i].name;
                nextPrayerTime = list[i].timeStr;
                const diff = list[i].time - now;
                const hours = Math.floor(diff / 3600000);
                const mins = Math.floor((diff % 3600000) / 60000);
                nextPrayerCountdown = `${hours}h ${mins}m`;
                break;
            }
        }
    }
    
    Component.onCompleted: {
        loadErbilPrayerTimes();
        updatePrayerTimes();
        timer.restart();
    }
    
    Timer {
        id: timer
        interval: 60000
        running: true
        repeat: true
        onTriggered: updatePrayerTimes()
    }
    
    Rectangle {
        anchors.fill: parent
        radius: window.s(20)
        color: mocha.base
        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
        border.width: 1
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: window.s(20)
            spacing: window.s(12)
            
            RowLayout {
                spacing: window.s(10)
                Text { text: "󰙾"; font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(22); color: mocha.mauve }
                Text { text: "Prayer Times"; font.family: "JetBrains Mono"; font.pixelSize: window.s(16); font.weight: Font.Black; color: mocha.text }
                Text { text: window.nextPrayerCountdown; font.family: "JetBrains Mono"; font.pixelSize: window.s(14); font.weight: Font.Medium; color: mocha.peach; Layout.alignment: Qt.AlignRight }
            }
            
            Rectangle { height: 1; color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08); Layout.fillWidth: true }
            
            Repeater {
                model: window.prayerTimes
                delegate: RowLayout {
                    spacing: window.s(12)
                    Text { 
                        text: model.name; 
                        font.family: "JetBrains Mono"; 
                        font.pixelSize: window.s(14); 
                        color: model.name === window.nextPrayer ? mocha.mauve : mocha.text;
                        font.weight: model.name === window.nextPrayer ? Font.Black : Font.Medium
                    }
                    Item { Layout.fillWidth: true }
                    Text { 
                        text: model.timeStr; 
                        font.family: "JetBrains Mono"; 
                        font.pixelSize: window.s(14); 
                        color: model.name === window.nextPrayer ? mocha.mauve : mocha.subtext0;
                        font.weight: model.name === window.nextPrayer ? Font.Black : Font.Medium
                    }
                }
            }
            
            Item { Layout.fillHeight: true }
            
            Text {
                text: "Close"
                font.family: "JetBrains Mono"; font.pixelSize: window.s(11); color: mocha.subtext0
                Layout.alignment: Qt.AlignRight
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh close"])
                    onEntered: parent.color = mocha.text
                    onExited: parent.color = mocha.subtext0
                }
            }
        }
    }
    
    function s(val) { return Math.round(val * (typeof scaleFunc === "function" ? scaleFunc() : 1)); }
}
