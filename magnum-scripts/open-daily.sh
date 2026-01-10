#!/bin/bash

DEST_DIR="${MO_DAILY_PATH:-$MO_BASE_PATH/Areas/Daily}"
TEMPLATE_PATH="$MO_BASE_PATH/Resources/Templates/Daily Template.md"

DATE=$(date +%Y-%m-%d)
FILE_PATH="$DEST_DIR/$DATE.md"

mkdir -p "$DEST_DIR"

if [ ! -f "$FILE_PATH" ]; then
    if [ -f "$TEMPLATE_PATH" ]; then
        cp "$TEMPLATE_PATH" "$FILE_PATH"
        echo "Создана новая заметка из шаблона: $DATE.md"
    else
        echo "Ошибка: Шаблон не найден по пути $TEMPLATE_PATH"
        touch "$FILE_PATH"
    fi
else
    echo "Заметка на сегодня уже существует, открываю..."
fi

$MO_EDITOR "$FILE_PATH"
