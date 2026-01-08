#!/bin/bash

SCR_PATH="/tmp/ocr_shot.png"

# 1. Захват
if ! slurp | grim -g - "$SCR_PATH"; then
    exit 0
fi

# 2. Подготовка (увеличиваем контраст и размер для точности)
# Требует пакет imagemagick. Если его нет, просто пропусти этот шаг.
mogrify -resize 200% -colorspace gray -levels 10%,90% "$SCR_PATH"

# 3. Распознавание
# Мы используем --psm 3 (Full automatic page segmentation), это самый надежный вариант
# для смеси горизонтального и вертикального текста.
# Список языков: eng и rus в начале, чтобы у них был приоритет.
LANGS="eng+rus+deu+jpn+jpn_vert+kor"

TEXT=$(tesseract "$SCR_PATH" - -l "$LANGS" --psm 3 2>/dev/null)

# 4. Обработка
if [ -z "$TEXT" ] || [[ "$TEXT" =~ ^[[:space:]]+$ ]]; then
    notify-send -a "OCR" "Ошибка" "Текст не найден"
else
    # Умная очистка:
    # Если в тексте много иероглифов (японский/корейский), убираем ВСЕ пробелы.
    # Если это европейский текст, просто схлопываем лишние переносы в один пробел.
    if [[ "$TEXT" =~ [ぁ-んァ-ヶ一-龠] ]]; then
        CLEAN_TEXT=$(echo "$TEXT" | tr -d '\f' | tr -d '[:space:]')
    else
        CLEAN_TEXT=$(echo "$TEXT" | tr -d '\f' | xargs)
    fi
    
    echo "$CLEAN_TEXT" | wl-copy
    notify-send -a "OCR" "Скопировано" "$CLEAN_TEXT"
fi

rm "$SCR_PATH"
