#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <output_dir>"
    exit 1
fi

OUT_DIR="$1"
mkdir -p "$OUT_DIR"

# Настройка качества (CQ). 
# 28-30 — хороший баланс. Чем выше число, тем меньше файл и ниже качество.
# Для анимации 30 обычно выглядит отлично.
QUALITY=30

find . -type f -name "*.mkv" -not -path "./$OUT_DIR/*" -print0 | while IFS= read -r -d '' file; do
    
    rel_path="${file#./}"
    out_file="$OUT_DIR/$rel_path"
    mkdir -p "$(dirname "$out_file")"
    
    if [ -f "$out_file" ]; then
        echo ">>> Пропуск: $rel_path"
        continue
    fi

    echo "--- Обработка (GPU): $rel_path ---"

    # Получаем высоту видео
    height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$file")
    height=${height:-0}

    # Настройки видеокарты NVIDIA:
    # -c:v hevc_nvenc: используем чип NVIDIA для видео
    # -preset p7: максимальное качество для энкодера видеокарты
    # -rc vbr: переменный битрейт
    # -cq: уровень качества
    # -pix_fmt p010le: 10-битный цвет (лучше для мультфильмов)
    video_settings="-c:v hevc_nvenc -preset p7 -rc vbr -cq $QUALITY -pix_fmt p010le"
    
    # Звук в Opus (80k — за глаза для этого сериала)
    audio_settings="-c:a libopus -b:a 80k -ac 2 -map 0:v:0 -map 0:a:0"

    if [ "$height" -gt 720 ]; then
        filter="-vf scale=-2:720"
        echo "Режим: 1080p -> 720p (GPU)"
    else
        filter=""
        echo "Режим: Сохранение разрешения $height p (GPU)"
    fi

    # Запуск
    ffmpeg -hwaccel cuda -i "$file" \
        $filter \
        $video_settings \
        $audio_settings \
        -c:s copy \
        -y "$out_file" </dev/null

    if [ $? -eq 0 ]; then
        echo "Успешно сконвертировано за $(SECONDS) сек."
    else
        echo "ОШИБКА на файле: $rel_path"
    fi
done
