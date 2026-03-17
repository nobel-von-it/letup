#!/bin/bash

# Файл, в который запишем результат
OUTPUT="video_data.csv"

# Заголовки таблицы
echo "filepath;filesize_mb;duration_sec;video_codec;width;height;bitrate_kbps;audio_info" > "$OUTPUT"

# Ищем все файлы mkv
find . -type f -name "*.mkv" | while read -r file; do
    # Получаем данные через ffprobe
    # v:c - кодек видео, w - ширина, h - высота, b:v - битрейт видео, size - размер, duration - длительность
    # a:c - кодек аудио
    metadata=$(ffprobe -v error -show_entries format=size,duration,bit_rate:stream=codec_name,width,height,codec_type -of csv=p=0 "$file")
    
    # Размер файла в МБ
    filesize_bytes=$(stat -c%s "$file")
    filesize_mb=$(echo "scale=2; $filesize_bytes / 1048576" | bc)

    # Собираем строку (путь к файлу;размер;длительность;кодек;ширина;высота;битрейт;аудио)
    # Очищаем путь от лишних точек в начале
    clean_path=$(echo "$file" | sed 's|^\./||')
    
    echo "$clean_path;$filesize_mb;$metadata" >> "$OUTPUT"
    
    echo "Обработан: $clean_path"
done

echo "------------------------------------------"
echo "Готово! Данные сохранены в файл: $OUTPUT"
echo "Загрузи этот файл сюда или скопируй его содержимое."
