#!/bin/bash

# Опции
opt1="Suspend"
opt2="Restart"
opt3="Shutdown"

# Вызов меню Fuzzel
# -d: dmenu mode
# -p: Подсказка
# -w: Ширина окна
# -l: Количество строк
selected=$(echo -e "$opt1\n$opt2\n$opt3" | fuzzel -d -p "Power > " -w 25 -l 3)

# Обработка выбора
case $selected in
    "$opt1")
        systemctl suspend
        ;;
    "$opt2")
        systemctl reboot
        ;;
    "$opt3")
        systemctl poweroff
        ;;
esac
