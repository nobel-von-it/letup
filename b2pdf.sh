#!/bin/bash

# Установка зависимостей
if [ "$1" = "-i" ] || [ "$1" = "--install" ]; then
    echo "Устанавливаю зависимости для b2pdf..."
    sudo apt update
    # pdfbook2 входит в texlive-extra-utils
    sudo apt install -y \
        pandoc \
        texlive-xetex \
        texlive-extra-utils \
        texlive-lang-cyrillic \
        ghostscript \
        djvulibre-bin \
        fonts-dejavu
    echo "Готово! Все зависимости установлены."
    exit 0
fi

if [ -z "$1" ]; then
    echo "Использование: $0 <файл_книги>"
    echo "         $0 -i | --install   — установить зависимости"
    exit 1
fi

INPUT_FILE="$1"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Ошибка: Файл '$INPUT_FILE' не найден."
    exit 1
fi

# Извлечение имен
FILENAME=$(basename "$INPUT_FILE")
BASENAME="${FILENAME%.*}"
EXTENSION="${FILENAME##*.}"
EXTENSION=$(echo "$EXTENSION" | tr '[:upper:]' '[:lower:]')

# Имена выходных файлов
A5_OUTPUT="${BASENAME}_A5.pdf"
PRINT_OUTPUT="${BASENAME}_PRINT.pdf"

echo "======================================"
echo "Исходный файл: $FILENAME"
echo "======================================"

# Функция для стандартизации PDF (обрезка полей, размер A5, зеркальные поля)
normalize_to_a5_book() {
    local input="$1"
    local output="$2"
    local temp_cropped="${output%.*}_temp_cropped.pdf"
    local temp_a5="${output%.*}_temp_a5.pdf"
    
    echo "Оптимизирую читаемость (обрезка полей, масштабирование)..."
    
    # 1. Сначала обрезаем лишние белые поля оригинала, оставляя небольшой отступ
    pdfcrop --margins '2 2 2 2' "$input" "$temp_cropped" > /dev/null 2>&1
    
    # 2. Приводим к формату A5 и нормализуем структуру через Ghostscript
    # Так как мы обрезали поля, текст теперь будет занимать максимум места на A5
    gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/printer \
       -dNOPAUSE -dQUIET -dBATCH -sPAPERSIZE=a5 \
       -dFIXEDMEDIA -dPDFFitPage \
       -sOutputFile="$temp_a5" "$temp_cropped"
       
    # 3. Добавляем стандартные книжные поля (с учетом зеркальности для переплета)
    # Используем масштаб 0.88 для баланса между размером текста и полями
    pdfjam --twoside --offset '5mm -1mm' --scale 0.88 --paper a5paper "$temp_a5" --outfile "$output" > /dev/null 2>&1
    
    rm "$temp_cropped" "$temp_a5"
}

# ЭТАП 1: Создание правильного A5
case "$EXTENSION" in
    epub|fb2)
        echo "Формат: $EXTENSION. Запускаю Pandoc (XeLaTeX)..."
        pandoc "$INPUT_FILE" -o "$A5_OUTPUT" \
            -V papersize:a5 \
            -V geometry:inner=17mm,outer=10mm,top=12mm,bottom=15mm \
            -V fontsize=11pt \
            -V documentclass=book \
            -V indent=true \
            -V lang=ru-RU \
            -V mainfont="DejaVu Serif" \
            --pdf-engine=xelatex
        ;;
        
    mobi|azw3)
        echo "Формат: $EXTENSION. Конвертирую через Calibre в EPUB..."
        TEMP_EPUB="${BASENAME}_temp.epub"
        ebook-convert "$INPUT_FILE" "$TEMP_EPUB" > /dev/null 2>&1
        
        echo "Запускаю Pandoc (XeLaTeX)..."
        pandoc "$TEMP_EPUB" -o "$A5_OUTPUT" \
            -V papersize:a5 \
            -V geometry:inner=17mm,outer=10mm,top=12mm,bottom=15mm \
            -V fontsize=11pt \
            -V documentclass=book \
            -V indent=true \
            -V lang=ru-RU \
            -V mainfont="DejaVu Serif" \
            --pdf-engine=xelatex
            
        rm "$TEMP_EPUB"
        ;;
        
    djvu)
        echo "Формат: DjVu. Конвертирую и стандартизирую..."
        TEMP_RAW="${BASENAME}_raw.pdf"
        ddjvu -format=pdf "$INPUT_FILE" "$TEMP_RAW"
        normalize_to_a5_book "$TEMP_RAW" "$A5_OUTPUT"
        rm "$TEMP_RAW"
        ;;
        
    pdf)
        echo "Формат: PDF. Запускаю процесс стандартизации..."
        normalize_to_a5_book "$INPUT_FILE" "$A5_OUTPUT"
        ;;
        
    *)
        echo "Ошибка: Формат .$EXTENSION не поддерживается."
        exit 1
        ;;
esac

# ЭТАП 2: Спуск полос и разбивка на тетради (pdfbook2)
if [ -f "$A5_OUTPUT" ]; then
    echo "Создаю версию для печати (спуск полос на тетради по 16 страниц)..."
    
    # --no-crop важен, чтобы pdfbook2 не "съедал" поля, которые мы создали выше
    pdfbook2 --no-crop --signature=16 --short-edge \
        --inner-margin 0 --outer-margin 0 --top-margin 0 --bottom-margin 0 \
        "$A5_OUTPUT" > /dev/null 2>&1
    
    # Переименовываем результат для красоты
    if [ -f "${BASENAME}_A5-book.pdf" ]; then
        mv "${BASENAME}_A5-book.pdf" "$PRINT_OUTPUT"
        echo "======================================"
        echo "ГОТОВО!"
        echo "Версия для экрана: $A5_OUTPUT"
        echo "Версия для ПЕЧАТИ: $PRINT_OUTPUT"
        echo "======================================"
    else
        echo "Ошибка при создании версии для печати. Проверьте установлен ли pdfbook2."
    fi
else
    echo "Ошибка: Файл A5 не был создан."
fi