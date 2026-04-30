#!/bin/bash
# pinentry-fuzzel: Используем fuzzel для ввода пароля GPG в Niri

# Лог для отладки
LOG="/tmp/pinentry.log"
echo "--- PINENTRY START $(date) ---" >> "$LOG"
echo "Env: WAYLAND_DISPLAY=$WAYLAND_DISPLAY, DISPLAY=$DISPLAY" >> "$LOG"

# Если переменные окружения отсутствуют, пробуем их восстановить
if [ -z "$WAYLAND_DISPLAY" ]; then
    export WAYLAND_DISPLAY="wayland-1"
fi
if [ -z "$DISPLAY" ]; then
    export DISPLAY=":0"
fi

echo "OK Pleased to meet you"
while read -r line; do
    echo "READ: $line" >> "$LOG"
    
    if [[ $line == GETPIN* ]]; then
        # Запрашиваем пароль через fuzzel
        # Мы используем --stdout, чтобы точно получить результат
        pin=$(fuzzel -d --prompt "🔒 Passphrase: " --password --lines 0 --width 30 2>>"$LOG")
        
        if [ -z "$pin" ]; then
            echo "ERR 83886179 cancelled"
            echo "RESULT: Cancelled or empty" >> "$LOG"
        else
            echo "D $pin"
            echo "OK"
            echo "RESULT: Success (hidden)" >> "$LOG"
        fi
    elif [[ $line == BYE* ]]; then
        echo "OK"
        echo "BYE received" >> "$LOG"
        exit 0
    else
        echo "OK"
    fi
done
