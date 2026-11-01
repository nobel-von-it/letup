#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Скрипт для конвертации EPUB в PDF-буклет (A4, тетради по 16 страниц/4 листа)
# ==============================================================================
# Зависимости для Arch Linux:
# sudo pacman -S pandoc-cli typst texlive-binextra (для pdfbook2 / pdfjam)
# ==============================================================================

# --- НАСТРОЙКИ ФОРМАТИРОВАНИЯ (Вынесены наверх для удобного редактирования) ---

# Параметры страницы для промежуточного PDF
PAGE_SIZE="a5"

# Внутренние отступы текста на страницах (A5)
# MARGIN_INSIDE — это отступ со стороны корешка (для сшивания), он должен быть больше.
# MARGIN_OUTSIDE — отступ со стороны внешнего края страницы.
MARGIN_INSIDE="15mm"
MARGIN_OUTSIDE="5mm"
MARGIN_TOP="5mm"
MARGIN_BOTTOM="5mm"

# Параметры шрифта текста
FONT_SIZE="11pt"
MAIN_FONT="Liberation Serif" # Убедитесь, что шрифт установлен в системе

# Параметры сборки буклета
SIGNATURE_SIZE=16 # 16 страниц в тетради (это 4 физических листа А4 с двусторонней печатью)

# --- КОНЕЦ НАСТРОЕК ---

if [ $# -lt 1 ]; then
    echo "=========================================================="
    echo "Использование:"
    echo "  $0 <входной_файл.epub> [выходной_файл.pdf]"
    echo ""
    echo "Если выходной файл не указан, он будет создан в той же папке"
    echo "с суффиксом _booklet.pdf"
    echo "=========================================================="
    exit 1
fi

INPUT_FILE="$1"

if [ ! -f "$INPUT_FILE" ]; then
    echo "❌ Ошибка: Файл '$INPUT_FILE' не найден."
    exit 1
fi

# Формируем имя выходного файла, если оно не задано
if [ -n "${2:-}" ]; then
    OUTPUT_FILE="$2"
else
    # Берем имя исходного файла без расширения и добавляем _booklet.pdf
    BASENAME="${INPUT_FILE%.*}"
    OUTPUT_FILE="${BASENAME}_booklet.pdf"
fi

# Временные файлы
TEMP_PDF="${OUTPUT_FILE%.pdf}_temp_a5.pdf"
META_YAML=$(mktemp --suffix=".yaml")

cat <<EOF > "$META_YAML"
margin:
  inside: $MARGIN_INSIDE
  outside: $MARGIN_OUTSIDE
  top: $MARGIN_TOP
  bottom: $MARGIN_BOTTOM
EOF

# Функция очистки временных файлов при выходе
cleanup() {
    if [ -f "$TEMP_PDF" ]; then
        rm -f "$TEMP_PDF"
    fi
    if [ -f "$META_YAML" ]; then
        rm -f "$META_YAML"
    fi
}
trap cleanup EXIT

echo "📖 Шаг 1: Конвертация EPUB в промежуточный PDF (A5) с использованием Pandoc и Typst..."
pandoc "$INPUT_FILE" \
    -o "$TEMP_PDF" \
    --pdf-engine=typst \
    --metadata-file="$META_YAML" \
    -V papersize="$PAGE_SIZE" \
    -V fontsize="$FONT_SIZE" \
    -V mainfont="$MAIN_FONT"

if [ ! -f "$TEMP_PDF" ]; then
    echo "❌ Ошибка при конвертации файла с помощью Pandoc."
    exit 1
fi

echo "🖨️  Шаг 2: Сборка буклета (спуск полос, тетради по $SIGNATURE_SIZE стр.)..."

# Предпочтительнее использовать pdfbook2, так как он позволяет точно обнулить внешние отступы
# и поддерживает печать по короткому краю (short-edge).
if command -v pdfbook2 &> /dev/null; then
    # pdfbook2 создает файл с именем <имя_исходника>-book.pdf
    TEMP_PDFBOOK_OUT="${TEMP_PDF%.pdf}-book.pdf"
    
    # Добавляем --paper=a4paper чтобы убрать гигантские отступы (иначе pdfbook2 использует letter)
    # Убираем --short-edge, чтобы страницы не переворачивались (так как принтер сам будет переворачивать по короткому краю)
    pdfbook2 --no-crop --paper=a4paper --signature="$SIGNATURE_SIZE" \
             --inner-margin 0 --outer-margin 0 --top-margin 0 --bottom-margin 0 \
             "$TEMP_PDF" >/dev/null

    if [ -f "$TEMP_PDFBOOK_OUT" ]; then
        mv "$TEMP_PDFBOOK_OUT" "$OUTPUT_FILE"
    else
        echo "❌ Ошибка: pdfbook2 не смог создать файл."
        exit 1
    fi
elif command -v pdfjam &> /dev/null; then
    # Альтернативный вариант через pdfjam
    # Добавляем хак с preamble для правильного переворота страниц при печати по короткому краю.
    pdfjam --quiet --landscape --signature "$SIGNATURE_SIZE" \
           --preamble '\usepackage{everyshi}\makeatletter\EveryShipout{\ifodd\c@page\pdfpageattr{/Rotate 180}\fi}\makeatother' \
           --outfile "$OUTPUT_FILE" "$TEMP_PDF"
    
    if [ ! -f "$OUTPUT_FILE" ]; then
         echo "❌ Ошибка при создании буклета с помощью pdfjam."
         exit 1
    fi
else
    echo "❌ Ошибка: Не найден ни pdfbook2, ни pdfjam (пакет texlive-binextra)."
    exit 1
fi

# Проверка результата
if [ -f "$OUTPUT_FILE" ]; then
    PAGE_COUNT=$(pdfinfo "$OUTPUT_FILE" 2>/dev/null | awk '/^Pages:/ {print $2}' || echo "н/д")
    echo "========================================================================="
    echo "✅ Готово! Результат сохранен в: $OUTPUT_FILE"
    echo "   Всего страниц (полос А4): $PAGE_COUNT"
    echo "========================================================================="
    echo "ВАЖНО: Инструкция для двусторонней печати:"
    echo "1. Откройте '$OUTPUT_FILE' в вашем PDF-ридере."
    echo "2. Выберите формат А4 и альбомную ориентацию (Landscape)."
    echo "3. Включите двустороннюю печать по КОРОТКОМУ КРАЮ (Short Edge)."
    echo "========================================================================="
else
    echo "❌ Произошла неизвестная ошибка, итоговый файл не был создан."
    exit 1
fi
