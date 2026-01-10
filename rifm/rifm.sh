#!/bin/bash

SCRIPT="$(realpath "$0")"
PWD="$(dirname "$SCRIPT")"
FILE="$PWD/main.py"
VENV_PATH="$PWD/.venv/bin/activate"

if [ -z "$1" ]; then
    echo "Ошибка: Укажите слово для поиска рифмы."
    echo "Пример: ./"$(basename $SCRIPT)" ослеплены"
    exit 1
fi

if [ ! -f "$VENV_PATH" ]; then
    echo "Ошибка: Виртуальное окружение не найдено по пути $VENV_PATH"
    exit 1
fi

source "$VENV_PATH"
python3 "$FILE" "$1"
deactivate
