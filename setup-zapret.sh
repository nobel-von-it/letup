#!/bin/bash


ORIG_USER=$(logname)

if [[ $EUID -ne 0 ]]; then
   echo "Запусти меня с sudo!" 
   exit 1
fi

if [[ -z "$1" ]]; then
   echo "Использование: sudo ./install_vault.sh <PATH_TO_ZAPRET_SCRIPT>"
   exit 1
fi

ZAPRET_SCRIPT_PATH=$(realpath "$1")

if [ ! -f "$ZAPRET_SCRIPT_PATH" ]; then
    echo "Неверный путь к скрипту: $ZAPRET_SCRIPT_PATH"
    exit 1
fi

ZAPRET_VISUDO_PATH="/etc/sudoers.d/zapret"
mkdir -p $(dirname "$ZAPRET_VISUDO_PATH")
ZAPRET_FILE_CONTENT="$ORIG_USER ALL=(ALL) NOPASSWD: $ZAPRET_SCRIPT_PATH"
echo "$ZAPRET_FILE_CONTENT" | sudo tee "$ZAPRET_VISUDO_PATH"

visudo -c "$ZAPRET_VISUDO_PATH" || exit 1

echo "Скрипт запрета успешно установлен!"

USER_SYSTEMD_ZAPRET_PATH="/home/$ORIG_USER/.config/systemd/user/zapret.service"

if [ -f "$USER_SYSTEMD_ZAPRET_PATH" ]; then
    echo "Скрипт запрета уже установлен."
else
    USER_SYSTEMD_ZAPRET_CONTENT="
[Unit]
Description=Запуск zapret-discord-youtube
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/sudo $ZAPRET_SCRIPT_PATH -nointeractive
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target"

    echo "$USER_SYSTEMD_ZAPRET_CONTENT" | sudo tee "$USER_SYSTEMD_ZAPRET_PATH"
fi

systemctl --user enable --now zapret
