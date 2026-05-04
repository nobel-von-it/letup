#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Пожалуйста, запустите скрипт с правами суперпользователя: sudo bash $0"
  exit 1
fi

echo "=== Этап 1: Радикальная чистка очередей ==="
echo "Отменяю зависшие задания печати..."
cancel -a

echo "Ищу старые настройки HP P2055dn..."
PRINTERS=$(lpstat -p | grep -i "2055" | awk '{print $2}')

if [ -z "$PRINTERS" ]; then
    echo "Старых профилей P2055dn не найдено."
else
    for p in $PRINTERS; do
        echo "Удаляю конфликтующий принтер: $p"
        lpadmin -x "$p"
    done
fi

echo "=== Этап 2: Установка драйверов и CUPS ==="
if command -v pacman >/dev/null 2>&1; then
    echo "Использую pacman для установки..."
    pacman -Sy --needed --noconfirm hplip cups
elif command -v apt >/dev/null 2>&1; then
    echo "Использую apt для установки..."
    apt update
    apt install -y hplip hplip-gui printer-driver-hpcups cups
else
    echo "Ошибка: Не найден подходящий менеджер пакетов (pacman или apt)."
    exit 1
fi

echo "=== Этап 3: Перезапуск системы печати ==="
systemctl enable --now cups
systemctl restart cups

echo "=========================================================="
echo "Подготовка завершена! Старый мусор удален."
echo "Теперь включите принтер и выполните Шаг 2 из инструкции."
echo "=========================================================="