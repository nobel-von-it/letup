#!/usr/bin/env python3
"""
Weather updater for ironbar.
Fetches from wttr.in and updates ironbar variables via 'ironbar var set'.
"""
import urllib.request
import subprocess
import json
from datetime import datetime

LOCATION = "Krasnoyarsk"


def ironbar_set(name, value):
    subprocess.run(["ironbar", "var", "set", name, str(value)],
                   capture_output=True)


def get_weather():
    try:
        req = urllib.request.Request(
            f"https://wttr.in/{LOCATION}?m&format=%c%t",
            headers={"User-Agent": "curl/7.0"}
        )
        with urllib.request.urlopen(req, timeout=10) as r:
            current = r.read().decode("utf-8").strip()
        # Only update if we got valid data (not empty)
        if current:
            ironbar_set("weather_current", current)
    except Exception as e:
        # Don't overwrite weather_current on failure — keep last good value
        print(f"[weather] current fetch failed: {e}")

    try:
        req = urllib.request.Request(
            f"https://wttr.in/{LOCATION}?format=j1",
            headers={"User-Agent": "curl/7.0"}
        )
        with urllib.request.urlopen(req, timeout=10) as r:
            data = json.loads(r.read().decode("utf-8"))

        for i, day in enumerate(data["weather"][:3]):
            date_obj = datetime.strptime(day["date"], "%Y-%m-%d")
            ironbar_set(f"weather_date_{i}", date_obj.strftime("%A"))
            ironbar_set(f"weather_avg_{i}",  day["avgtempC"])
            ironbar_set(f"weather_high_{i}", day["maxtempC"])
            ironbar_set(f"weather_low_{i}",  day["mintempC"])
    except Exception as e:
        print(f"[weather] forecast fetch failed: {e}")


if __name__ == "__main__":
    get_weather()
