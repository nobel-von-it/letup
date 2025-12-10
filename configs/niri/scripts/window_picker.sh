#!/bin/bash

# Важно: флаг --json обязателен для работы jq
WINDOWS=$(niri msg --json windows)

# Парсим JSON:
# 1. .[] - берем каждое окно
# 2. Форматируем строку: "ID [AppID] Заголовок"
# 3. .app_id // "Unknown" - если ID нет (XWayland), пишем Unknown
LIST=$(echo "$WINDOWS" | jq -r '.[] | "\(.id)\t[\(.app_id // "Unknown")] \(.title)"')

# Запускаем Fuzzel
# -d (dmenu mode)
# --width 80 (ширина)
SELECTED=$(echo "$LIST" | fuzzel -d --prompt="Window > " --width 80 --lines 15)

if [ -z "$SELECTED" ]; then
    exit 0
fi

WINDOW_ID=$(echo "$SELECTED" | awk '{print $1}')

niri msg action focus-window --id "$WINDOW_ID"
