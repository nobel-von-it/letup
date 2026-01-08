#!/bin/bash

# Пути (проверь, чтобы путь к venv был правильным)
VENV_PATH="$HOME/Downloads/Git/letup/manga-ocr/.venv/bin/activate"
SCR_PATH="/tmp/ocr_shot.png"

# 1. Захват области
if ! slurp | grim -g - "$SCR_PATH"; then
    exit 0
fi

# 2. Быстрая разведка (Tesseract)
# Используем минимальный набор для детекции
SCOUT_TEXT=$(tesseract "$SCR_PATH" - -l eng+jpn --psm 3 2>/dev/null)

# 3. Логика выбора движка
# Проверяем, есть ли в тексте японские иероглифы (Кандзи) или Хирагана/Катакана
if [[ "$SCOUT_TEXT" =~ [ぁ-んァ-ヶ一-龠] ]]; then
    # ОБНАРУЖЕН ЯПОНСКИЙ -> Используем Нейросеть
    notify-send -a "OCR" -t 1500 "Анализ..." "Обнаружен японский язык, запускаю ИИ..."
    
    # Запуск нейросети
    FINAL_TEXT=$(source "$VENV_PATH" && python -c "from manga_ocr import MangaOcr; mocr = MangaOcr(); print(mocr('$SCR_PATH'))" 2>/dev/null)
else
    # ЯПОНСКИЙ НЕ НАЙДЕН -> Используем стандартный Tesseract
    # Перезапускаем его с полным набором языков для качества
    FINAL_TEXT=$(tesseract "$SCR_PATH" - -l eng+rus+deu --psm 3 2>/dev/null | tr -d '\f' | xargs)
fi

# 4. Копирование и финальное уведомление
if [ -z "$FINAL_TEXT" ] || [[ "$FINAL_TEXT" =~ ^[[:space:]]+$ ]]; then
    notify-send -a "OCR" "Ошибка" "Текст не распознан"
else
    echo "$FINAL_TEXT" | wl-copy
    notify-send -a "OCR" "Текст скопирован" "$FINAL_TEXT"
fi

rm "$SCR_PATH"
