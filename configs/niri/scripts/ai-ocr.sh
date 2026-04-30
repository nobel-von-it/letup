#!/bin/bash

VENV_PATH="$HOME/Downloads/Git/letup/manga-ocr/.venv/bin/activate"
SCR_PATH="/tmp/ocr_shot.png"

if ! slurp | grim -g - "$SCR_PATH"; then
    exit 0
fi

# Detect Japanese characters for AI engine selection
SCOUT_TEXT=$(tesseract "$SCR_PATH" - -l eng+jpn --psm 3 2>/dev/null)

if [[ "$SCOUT_TEXT" =~ [ぁ-んァ-ヶ一-龠] ]]; then
    notify-send -a "OCR" -t 1500 "Анализ..." "Обнаружен японский язык, запускаю ИИ..."
    FINAL_TEXT=$(source "$VENV_PATH" && python -c "from manga_ocr import MangaOcr; mocr = MangaOcr(); print(mocr('$SCR_PATH'))" 2>/dev/null)
else
    FINAL_TEXT=$(tesseract "$SCR_PATH" - -l eng+rus+deu --psm 3 2>/dev/null | tr -d '\f' | xargs)
fi

if [ -z "$FINAL_TEXT" ] || [[ "$FINAL_TEXT" =~ ^[[:space:]]+$ ]]; then
    notify-send -a "OCR" "Ошибка" "Текст не распознан"
else
    echo "$FINAL_TEXT" | wl-copy
    notify-send -a "OCR" "Текст скопирован" "$FINAL_TEXT"
fi

rm "$SCR_PATH"
