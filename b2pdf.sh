#!/bin/bash

if [ -z "$1" ]; then
    echo "Использование: $0 <файл_книги>"
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
        echo "Формат: DjVu. Конвертирую напрямую..."
        ddjvu -format=pdf "$INPUT_FILE" "$A5_OUTPUT"
        ;;
        
    *)
        echo "Ошибка: Формат .$EXTENSION не поддерживается."
        exit 1
        ;;
esac

# ЭТАП 2: Спуск полос и разбивка на тетради (pdfbook2)
if [ -f "$A5_OUTPUT" ]; then
    echo "Создаю версию для печати (спуск полос на тетради по 16 страниц)..."
    
    # pdfbook2 по умолчанию создает файл с приставкой -book
    pdfbook2 --signature=16 --short-edge "$A5_OUTPUT" > /dev/null 2>&1
    
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