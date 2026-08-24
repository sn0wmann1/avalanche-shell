import QtQuick
import QtQuick.Layouts
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
    property var notifiedPrayers: ({})
    
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
        
        // Find next prayer
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
        
        // Check if we should notify for upcoming prayer
        checkPrayerNotification(list, now);
    }
    
    function checkPrayerNotification(list, now): void {
        for (let i = 0; i < list.length; i++) {
            const prayer = list[i];
            const diff = prayer.time - now;
            const mins = diff / 60000;
            
            // Notify 5 minutes before prayer
            if (mins > 0 && mins <= 5 && !notifiedPrayers[prayer.name + prayer.timeStr]) {
                notifiedPrayers[prayer.name + prayer.timeStr] = true;
                showPrayerNotification(prayer);
            }
        }
    }
    
    function showPrayerNotification(prayer): void {
        const adhanPath = Quickshell.env("HOME") + "/Dotfiles/quickshell/caelestia/assets/adhan.png";
        Quickshell.execDetached(["notify-send", "-u", "normal", "-i", adhanPath, "Prayer Time", `${prayer.name} in 5 minutes (${prayer.timeStr})`]);
    }
    
    Component.onCompleted: {
        loadErbilPrayerTimes();
        updatePrayerTimes();
        // Update every minute
        timer.restart();
    }
    
    Timer {
        id: timer
        interval: 60000
        running: true
        repeat: true
        onTriggered: updatePrayerTimes()
    }
}
