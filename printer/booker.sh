#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
TEMPLATE="$SCRIPT_DIR/booker_template.typ"
LUA_FILTER="$SCRIPT_DIR/booker_filter.lua"

INPUT_FILE="$1"

if [ -z "$INPUT_FILE" ]; then
    echo "Использование: booker <файл.epub | файл.fb2>"
    exit 1
fi

BASENAME=$(basename "$INPUT_FILE")
BASENAME_NOEXT="${BASENAME%.*}"

INTERMEDIATE="${BASENAME_NOEXT}.typ"
OUTPUT_FILE="${BASENAME_NOEXT}.pdf"
BOOKLET_FILE="${BASENAME_NOEXT}_booklet.pdf"
MEDIA_DIR="${BASENAME_NOEXT}_media"

echo "==> Очистка AST и парсинг $BASENAME через Pandoc..."

pandoc "$INPUT_FILE" \
    --to=typst \
    --template="$TEMPLATE" \
    --wrap=none \
    --extract-media="$MEDIA_DIR" \
    --lua-filter="$LUA_FILTER" \
    --output="$INTERMEDIATE"

echo "==> Компиляция $INTERMEDIATE через Typst..."

typst compile "$INTERMEDIATE" "$OUTPUT_FILE"

echo "==> Спуск полос (создание книжных тетрадей)..."
if command -v pdfjam &> /dev/null; then
    pdfjam --quiet --landscape --signature '16' \
           --outfile "$BOOKLET_FILE" "$OUTPUT_FILE"
    echo "==> Успех: $BOOKLET_FILE"
    echo "==> При печати выбери: 'Двусторонняя печать по КОРОТКОМУ краю'"
else
    echo "ВНИМАНИЕ: pdfjam не найден в системе. Сгенерирован обычный файл $OUTPUT_FILE."
    echo "Установи pdfjam (входит в texlive-binextra или texlive-core), чтобы собирать буклеты."
fi
