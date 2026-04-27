#!/bin/bash

# ==========================================
# Установка зависимостей
# ==========================================
if [ "$1" = "-i" ] || [ "$1" = "--install" ]; then
    echo "Устанавливаю зависимости..."
    sudo apt update
    sudo apt install -y pandoc texlive-xetex texlive-extra-utils texlive-latex-extra texlive-lang-cyrillic ghostscript djvulibre-bin fonts-dejavu calibre
    echo "Готово!"
    exit 0
fi

if [ -z "$1" ]; then
    echo "Использование: $0 <файл_книги>"
    exit 1
fi

INPUT_FILE="$1"
FILENAME=$(basename "$INPUT_FILE")
BASENAME="${FILENAME%.*}"
EXTENSION="${FILENAME##*.}"
EXTENSION=$(echo "$EXTENSION" | tr '[:upper:]' '[:lower:]')

A5_OUTPUT="${BASENAME}_A5.pdf"
PRINT_OUTPUT="${BASENAME}_PRINT.pdf"

echo "======================================"
echo "Исходный файл: $FILENAME"
echo "======================================"

# ==========================================
# Создание LaTeX-преамбулы (Только для текстовых форматов)
# ==========================================
HEADER_TEX=$(mktemp)
cat << 'EOF' > "$HEADER_TEX"
\usepackage{fancyhdr}
\pagestyle{fancy}
\fancyhf{}
\fancyhead[LE,RO]{\small\thepage}
\fancyhead[RE]{\parbox[b]{0.9\textwidth}{\raggedleft\small\linespread{0.9}\selectfont\nouppercase{\leftmark}}}
\fancyhead[LO]{\parbox[b]{0.9\textwidth}{\raggedright\small\linespread{0.9}\selectfont\nouppercase{\rightmark}}}
\renewcommand{\headrulewidth}{0.4pt}
\usepackage{microtype}
\sloppy
\emergencystretch=1.5em
\setlength{\parskip}{0pt}
\setlength{\parindent}{1.5em}
EOF

# ==========================================
# ЭТАП 1: Создание правильного A5
# ==========================================
case "$EXTENSION" in
    epub|fb2|mobi|azw3)
        TARGET_FILE="$INPUT_FILE"
        if [[ "$EXTENSION" == "mobi" || "$EXTENSION" == "azw3" ]]; then
            TARGET_FILE="${BASENAME}_temp.epub"
            ebook-convert "$INPUT_FILE" "$TARGET_FILE" > /dev/null 2>&1
        fi

        echo "Верстаю книгу с идеальными полями..."
        # Задаем ваши отступы: внутри 18мм, снаружи 8мм, верх/низ 10мм
        pandoc "$TARGET_FILE" -o "$A5_OUTPUT" \
            --pdf-engine=xelatex \
            -V papersize=a5 \
            -V fontsize=11pt \
            -V documentclass=book \
            -V classoption=twoside \
            -V geometry:inner=18mm,outer=8mm,top=14mm,bottom=8mm,includehead,headheight=24pt,headsep=14pt \
            -V lang=ru-RU \
            -V mainfont="DejaVu Serif" \
            -V linestretch=1.05 \
            -H "$HEADER_TEX"
            
        if [[ "$TARGET_FILE" == *"_temp.epub" ]]; then rm "$TARGET_FILE"; fi
        ;;
        
    djvu|pdf)
        echo "Формат: $EXTENSION. Подгоняю рамки под А5..."
        
        TEMP_RAW="$INPUT_FILE"
        if [ "$EXTENSION" = "djvu" ]; then
            TEMP_RAW="${BASENAME}_raw.pdf"
            ddjvu -format=pdf "$INPUT_FILE" "$TEMP_RAW"
        fi

        # Логика для PDF:
        # 1. --trim '12mm 15mm 12mm 15mm': Отрезаем оригинальные белые края исходника.
        # 2. --scale 0.93: Слегка уменьшаем оставшийся блок текста, чтобы он точно 
        #    поместился на А5 и сформировал ваши поля 0.8-1см.
        # 3. --offset '5mm 0mm': Сдвигаем всё на 5мм от центра для корешка (в сумме даст ~1.8см внутри).
        
        pdfjam --twoside \
            --trim '12mm 15mm 12mm 15mm' --clip true \
            --scale 1 \
            --offset '5mm 0mm' \
            --paper a5paper \
            "$TEMP_RAW" --outfile "$A5_OUTPUT" > /dev/null 2>&1

        if [ "$EXTENSION" = "djvu" ]; then rm "$TEMP_RAW"; fi
        ;;
        
    *)
        echo "Ошибка: Формат не поддерживается."
        rm -f "$HEADER_TEX"
        exit 1
        ;;
esac

rm -f "$HEADER_TEX"

# ==========================================
# ЭТАП 2: Спуск полос
# ==========================================
if [ -f "$A5_OUTPUT" ]; then
    echo "Создаю тетради для печати..."
    pdfbook2 --no-crop --signature=16 --short-edge \
        --inner-margin 0 --outer-margin 0 --top-margin 0 --bottom-margin 0 \
        "$A5_OUTPUT" > /dev/null 2>&1
    
    if [ -f "${BASENAME}_A5-book.pdf" ]; then
        mv "${BASENAME}_A5-book.pdf" "$PRINT_OUTPUT"
        echo "ГОТОВО! ЭКРАН: $A5_OUTPUT | ПЕЧАТЬ: $PRINT_OUTPUT"
    fi
fi