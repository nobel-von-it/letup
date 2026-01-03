#!/bin/bash

# Пути
VENV_PATH="$HOME/Downloads/Git/letup/manga-ocr/.venv/bin/activate"
SCR_PATH="/tmp/ocr_shot.png"

# 1. Захват области
if ! slurp | grim -g - "$SCR_PATH"; then
    exit 0
fi

# 2. Распознавание
# Мы запускаем короткий Python-код, который использует manga-ocr
# Это работает НАМНОГО лучше Tesseract для японского
RESULT=$(source "$VENV_PATH" && python -c "from manga_ocr import MangaOcr; mocr = MangaOcr(); print(mocr('$SCR_PATH'))" 2>/dev/null)

# 3. Обработка результата
if [ -z "$RESULT" ]; then
    # Если нейросеть не справилась (например, там вообще нет японского), 
    # можно запустить Tesseract как запасной вариант для английского
    RESULT=$(tesseract "$SCR_PATH" - -l eng+rus --psm 3 2>/dev/null | tr -d '\f' | xargs)
fi

# 4. Копирование и уведомление
if [ -n "$RESULT" ]; then
    echo "$RESULT" | wl-copy
    notify-send -a "Neural OCR" "Текст скопирован" "$RESULT"
else
    notify-send -a "Neural OCR" "Ошибка" "Не удалось распознать текст"
fi

rm "$SCR_PATH"
