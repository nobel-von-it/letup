#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
TEMPLATE="$SCRIPT_DIR/booker_template.typ"
LUA_FILTER="$SCRIPT_DIR/booker_filter.lua"

if [ $# -lt 1 ]; then
    echo "=========================================================="
    echo "  Booker — Генератор печатных буклетов и книжных тетрадей"
    echo "=========================================================="
    echo "Использование:"
    echo "  $0 <папка_со_статьями_md> [Название_буклета]"
    echo "  $0 <файл.md | файл.epub | файл.fb2> [Название_буклета]"
    echo ""
    echo "Примеры:"
    echo "  $0 ./sites-parser/test-booklet \"Aeon Essays Collection\""
    echo "  $0 ./article.md"
    echo "=========================================================="
    exit 1
fi

INPUT_PATH="$1"
BOOK_TITLE="${2:-}"
TEMP_COMBINED=""

# Функция очистки временных файлов при выходе
cleanup() {
    if [ -n "$TEMP_COMBINED" ] && [ -f "$TEMP_COMBINED" ]; then
        rm -f "$TEMP_COMBINED"
    fi
}
trap cleanup EXIT

# 1. Обработка директории с Markdown-статьями
if [ -d "$INPUT_PATH" ]; then
    DIR_NAME=$(basename "$(realpath "$INPUT_PATH")")
    if [ -z "$BOOK_TITLE" ]; then
        BOOK_TITLE="$DIR_NAME"
    fi

    BASENAME_NOEXT="${DIR_NAME}"
    TEMP_COMBINED=$(mktemp --suffix=".md")

    echo "==> Обнаружена папка со статьями: $INPUT_PATH"
    echo "==> Название сборника: '$BOOK_TITLE'"
    
    # Находим все .md файлы в отсортированном порядке
    mapfile -t MD_FILES < <(find "$INPUT_PATH" -maxdepth 1 -name "*.md" | sort)

    if [ ${#MD_FILES[@]} -eq 0 ]; then
        echo "[-] Ошибка: В папке $INPUT_PATH не найдено файлов с расширением .md"
        exit 1
    fi

    echo "==> Найдено статей: ${#MD_FILES[@]}"
    for f in "${MD_FILES[@]}"; do
        echo "    • $(basename "$f")"
    done

    # Создаём объединённый Markdown с титульной шапкой
    cat << EOF > "$TEMP_COMBINED"
---
title: "$BOOK_TITLE"
author: "Сборник статей"
lang: "ru"
---

EOF

    for f in "${MD_FILES[@]}"; do
        # Удаляем индивидуальный YAML-frontmatter каждой статьи, чтобы не ломать Pandoc
        python3 -c '
import sys, re
with open(sys.argv[1], "r", encoding="utf-8") as file:
    content = file.read()
# Убираем блок --- ... ---
clean = re.sub(r"^---\n.*?\n---\n+", "", content, flags=re.DOTALL)
print(clean.strip())
print("\n\n")
' "$f" >> "$TEMP_COMBINED"
    done

    ACTUAL_INPUT="$TEMP_COMBINED"
    USE_FILTER=false

else
    # 2. Обработка отдельного файла
    if [ ! -f "$INPUT_PATH" ]; then
        echo "[-] Ошибка: Файл или папка '$INPUT_PATH' не существует."
        exit 1
    fi

    FILENAME=$(basename "$INPUT_PATH")
    BASENAME_NOEXT="${FILENAME%.*}"
    ACTUAL_INPUT="$INPUT_PATH"

    if [[ "$FILENAME" == *.md ]]; then
        USE_FILTER=false
    else
        USE_FILTER=true
    fi
fi

INTERMEDIATE="${BASENAME_NOEXT}.typ"
OUTPUT_FILE="${BASENAME_NOEXT}.pdf"
BOOKLET_FILE="${BASENAME_NOEXT}_booklet.pdf"
MEDIA_DIR="${BASENAME_NOEXT}_media"

echo "==> Конвертация $BASENAME_NOEXT через Pandoc..."

PANDOC_CMD=(pandoc "$ACTUAL_INPUT" \
    --to=typst \
    --template="$TEMPLATE" \
    --wrap=none \
    --extract-media="$MEDIA_DIR")

if [ "$USE_FILTER" = true ] && [ -f "$LUA_FILTER" ]; then
    PANDOC_CMD+=(--lua-filter="$LUA_FILTER")
fi

if [ -n "$BOOK_TITLE" ]; then
    PANDOC_CMD+=(-V "title=$BOOK_TITLE")
fi

PANDOC_CMD+=(--output="$INTERMEDIATE")

"${PANDOC_CMD[@]}"

# Исправление тонкостей синтаксиса Typst при вызовах функций и пунктуации (например: #emph[...](...) )
sed -i -E 's/(#[a-zA-Z0-9_]+\[[^]]*\])\(/\1 (/g' "$INTERMEDIATE"

echo "==> Компиляция A5 PDF через Typst..."
typst compile "$INTERMEDIATE" "$OUTPUT_FILE"

echo "==> Спуск полос (создание книжных тетрадей для печати)..."
PAGE_COUNT=$(pdfinfo "$OUTPUT_FILE" 2>/dev/null | awk '/^Pages:/ {print $2}' || echo "0")

if command -v pdfbook2 &> /dev/null; then
    SIG_OPT=""
    if [ "${PAGE_COUNT:-0}" -le 48 ] 2>/dev/null; then
        echo "==> Объем: $PAGE_COUNT стр. Верстка: Единая брошюра со сгибом по центру (short-edge)"
    else
        echo "==> Объем: $PAGE_COUNT стр. Верстка: Книжные тетради по 16 страниц (short-edge)"
        SIG_OPT="--signature=16"
    fi

    pdfbook2 --no-crop --short-edge $SIG_OPT \
             --inner-margin 0 --outer-margin 0 --top-margin 0 --bottom-margin 0 \
             "$OUTPUT_FILE" >/dev/null

    if [ -f "${BASENAME_NOEXT}-book.pdf" ]; then
        mv "${BASENAME_NOEXT}-book.pdf" "$BOOKLET_FILE"
    fi
elif command -v pdfjam &> /dev/null; then
    if [ "${PAGE_COUNT:-0}" -le 48 ] 2>/dev/null; then
        pdfjam --quiet --landscape --booklet true \
               --preamble '\usepackage{everyshi}\makeatletter\EveryShipout{\ifodd\c@page\pdfpageattr{/Rotate 180}\fi}\makeatother' \
               --outfile "$BOOKLET_FILE" "$OUTPUT_FILE" 2>/dev/null || \
        pdfjam --quiet --landscape --booklet true --outfile "$BOOKLET_FILE" "$OUTPUT_FILE"
    else
        pdfjam --quiet --landscape --signature '16' \
               --preamble '\usepackage{everyshi}\makeatletter\EveryShipout{\ifodd\c@page\pdfpageattr{/Rotate 180}\fi}\makeatother' \
               --outfile "$BOOKLET_FILE" "$OUTPUT_FILE" 2>/dev/null || \
        pdfjam --quiet --landscape --signature '16' --outfile "$BOOKLET_FILE" "$OUTPUT_FILE"
    fi
else
    echo "ВНИМАНИЕ: pdfbook2 / pdfjam не найдены в системе. Сгенерирован обычный файл $OUTPUT_FILE."
fi

if [ -f "$BOOKLET_FILE" ]; then
    SHEET_COUNT=$(pdfinfo "$BOOKLET_FILE" 2>/dev/null | awk '/^Pages:/ {print $2}' || echo "н/д")

    echo "=========================================================="
    echo " [✓] Успешно создан буклет!"
    echo "=========================================================="
    echo " • A5 исходник:    $OUTPUT_FILE ($PAGE_COUNT стр.)"
    echo " • Готовый буклет: $BOOKLET_FILE ($SHEET_COUNT листов A4)"
    echo ""
    echo " 🖨️  Инструкция по печати:"
    echo "   1. Откройте $BOOKLET_FILE (или отправьте: lp $BOOKLET_FILE)"
    echo "   2. В параметрах печати выберите: 'Двусторонняя печать по КОРОТКОМУ краю'"
    echo "   3. Сложите полученные листы пополам в тетради и сшейте."
    echo "=========================================================="
fi
