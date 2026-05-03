#!/usr/bin/env python3

import json
import urllib.request
import sys

WEATHER_CODES = {
    '113': '󰖙',
    '116': '󰖕',
    '119': '󰖐',
    '122': '󰖐',
    '143': '󰖑',
    '176': '󰖗',
    '179': '󰖗',
    '182': '󰖗',
    '185': '󰖗',
    '200': '󰙾',
    '227': '󰼶',
    '230': '󰼶',
    '248': '󰖑',
    '260': '󰖑',
    '263': '󰖗',
    '266': '󰖗',
    '281': '󰖗',
    '284': '󰖗',
    '293': '󰖗',
    '296': '󰖗',
    '299': '󰖗',
    '302': '󰖗',
    '305': '󰖗',
    '308': '󰖗',
    '311': '󰖗',
    '314': '󰖗',
    '317': '󰖗',
    '320': '󰼶',
    '323': '󰼶',
    '326': '󰼶',
    '329': '󰼶',
    '332': '󰼶',
    '335': '󰼶',
    '338': '󰼶',
    '350': '󰖗',
    '353': '󰖗',
    '356': '󰖗',
    '359': '󰖗',
    '362': '󰖗',
    '365': '󰖗',
    '368': '󰼶',
    '371': '󰼶',
    '374': '󰖗',
    '377': '󰖗',
    '386': '󰙾',
    '389': '󰙾',
    '392': '󰙾',
    '395': '󰼶'
}

def get_weather():
    try:
        with urllib.request.urlopen("https://wttr.in/Krasnoyarsk?format=j1") as response:
            data = json.loads(response.read().decode())
            
            current = data['current_condition'][0]
            temp = current['temp_C']
            code = current['weatherCode']
            icon = WEATHER_CODES.get(code, "󰖐")
            desc = current['weatherDesc'][0]['value']
            
            feels_like = current['FeelsLikeC']
            humidity = current['humidity']
            wind = current['windspeedKmph']
            
            location = data['nearest_area'][0]['areaName'][0]['value']
            
            tooltip = f"<b>{location}</b>\n"
            tooltip += f"Currently: {desc} {temp}°C\n"
            tooltip += f"Feels like: {feels_like}°C\n"
            tooltip += f"Humidity: {humidity}%\n"
            tooltip += f"Wind: {wind} km/h\n\n"
            
            tooltip += "<b>Forecast:</b>\n"
            for day in data['weather'][:3]:
                date = day['date']
                max_t = day['maxtempC']
                min_t = day['mintempC']
                day_code = day['hourly'][4]['weatherCode']
                day_icon = WEATHER_CODES.get(day_code, "󰖐")
                tooltip += f"{date}: {day_icon} {max_t}° / {min_t}°\n"
            
            out = {
                "text": f"{icon} {temp}°C",
                "tooltip": tooltip,
                "class": "weather"
            }
            return json.dumps(out)
    except Exception as e:
        return json.dumps({"text": "󰖪 N/A", "tooltip": str(e)})

if __name__ == "__main__":
    print(get_weather())
