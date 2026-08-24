#!/usr/bin/env bash
set -euo pipefail

PRAYER_JSON="$HOME/Dotfiles/quickshell/caelestia/assets/prayer-times/erbil.json"

if [ ! -f "$PRAYER_JSON" ]; then
    echo '{"nextPrayer":"","nextPrayerTime":"","nextPrayerCountdown":""}'
    exit 0
fi

python3 - "$PRAYER_JSON" <<'PYEOF'
import json, sys
from datetime import datetime, timedelta

path = sys.argv[1]
now = datetime.now()
mmdd = now.strftime("%m-%d")

with open(path) as f:
    data = json.load(f)

timings = None
for entry in data:
    if entry["date"] == mmdd:
        timings = entry
        break

if not timings:
    print('{"nextPrayer":"","nextPrayerTime":"","nextPrayerCountdown":""}')
    sys.exit(0)

names = ["fajr", "dhuhr", "asr", "maghrib", "isha"]
for name in names:
    time_str = timings.get(name, "")
    if not time_str:
        continue
    h, m = map(int, time_str.split(":"))
    prayer_time = now.replace(hour=h, minute=m, second=0, microsecond=0)
    if prayer_time < now:
        prayer_time += timedelta(days=1)
    diff = prayer_time - now
    hours = diff.seconds // 3600
    mins = (diff.seconds % 3600) // 60
    print(f'{{"nextPrayer":"{name}","nextPrayerTime":"{time_str}","nextPrayerCountdown":"{hours}h {mins}m"}}')
    sys.exit(0)

print('{"nextPrayer":"","nextPrayerTime":"","nextPrayerCountdown":""}')
PYEOF
