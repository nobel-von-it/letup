#!/bin/bash

# Путь к самому скрипту (чтобы найти шаблон в той же папке)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_NAME="book_template.typ"
TEMPLATE_PATH="$SCRIPT_DIR/$TEMPLATE_NAME"

# Проверка наличия шаблона
if [ ! -f "$TEMPLATE_PATH" ]; then
    echo "Ошибка: Шаблон $TEMPLATE_NAME не найден в $SCRIPT_DIR"
    exit 1
fi

# Входные параметры
INPUT_BOOK=$(realpath "$1")
OUTPUT_DIR=$(realpath "$2")

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Использование: $0 <путь_к_книге.epub> <папка_вывода>"
    exit 1
fi

# Создаем папку вывода, если её нет
mkdir -p "$OUTPUT_DIR"

# Подготовка имен файлов
BASENAME=$(basename "$INPUT_BOOK" .epub)
TEMP_DIR=$(mktemp -d) # Временная папка для сборки

echo "[1/4] Подготовка окружения..."
# Копируем шаблон во временную папку, чтобы Typst видел его "рядом"
cp "$TEMPLATE_PATH" "$TEMP_DIR/"

echo "[2/4] Извлечение контента и изображений..."
(cd "$TEMP_DIR" && pandoc "$INPUT_BOOK" --extract-media=. -t typst -o content.typ)

echo "[2.5/4] Очистка Typst-кода от сломанных ссылок EPUB..."
# 1. Удаляем #link(<метка>). 
# Конструкция #link(<метка>)[Текст] превратится просто в [Текст], что Typst воспримет как обычный текстовый блок.
sed -i -E 's/#link\(<[^>]+>\)//g' "$TEMP_DIR/content.typ"

# 2. Удаляем висячие метки вида <метка> в конце абзацев и блоков.
sed -i -E 's/<[a-zA-Z0-9._-]+>//g' "$TEMP_DIR/content.typ"

echo "[3/4] Верстка и компиляция..."
# Создаем главный файл сборки внутри TEMP_DIR
cat << EOF > "$TEMP_DIR/main.typ"
#import "$TEMPLATE_NAME": book

#show: book.with(
  title: "$BASENAME",
  author: "Библиотека"
)

#include "content.typ"
EOF

# Компилируем, находясь внутри временной папки
(cd "$TEMP_DIR" && typst compile main.typ "compiled.pdf")

echo "[4/4] Сборка тетрадей..."
# Финальный спуск полос сразу в папку назначения
pdfjam --signature 16 --landscape \
       --outfile "$OUTPUT_DIR/${BASENAME}_print.pdf" \
       "$TEMP_DIR/compiled.pdf"

# Очистка
rm -rf "$TEMP_DIR"

echo "Готово! Книга сохранена в: $OUTPUT_DIR/${BASENAME}_print.pdf"