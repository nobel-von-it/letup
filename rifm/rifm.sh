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
    echo "Создание виртуального окружения..."
    python3 -m venv "$PWD/.venv"

    if [ $? -eq 0 ]; then
        echo "Виртуальное окружение успешно создано."
    fi

    source "$VENV_PATH"
    echo "Установка зависимостей..."
    pip3 install -r "$PWD/requirements.txt"

    if [ $? -eq 0 ]; then
        echo "Зависимости успешно установлены."
    fi

    deactivate

    exit 1
fi

source "$VENV_PATH"
python3 "$FILE" "$1"
deactivate
