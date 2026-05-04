#!/bin/bash

if [ "$1" = "-i" ] || [ "$1" = "--install" ]; then
    echo "Устанавливаю зависимости..."
    if command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --needed --noconfirm pandoc texlive-basic texlive-latex texlive-latexextra texlive-fontsrecommended texlive-fontsextra texlive-xetex texlive-langcyrillic ghostscript djvulibre ttf-dejavu calibre texlive-doc
    elif command -v apt >/dev/null 2>&1; then
        sudo apt update
        sudo apt install -y pandoc texlive-xetex texlive-extra-utils texlive-latex-extra texlive-lang-cyrillic ghostscript djvulibre-bin fonts-dejavu calibre
    else
        echo "Ошибка: Не найден подходящий менеджер пакетов (pacman или apt)."
        exit 1
    fi
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

case "$EXTENSION" in
    epub|fb2|mobi|azw3)
        TARGET_FILE="$INPUT_FILE"
        if [[ "$EXTENSION" == "mobi" || "$EXTENSION" == "azw3" ]]; then
            TARGET_FILE="${BASENAME}_temp.epub"
            ebook-convert "$INPUT_FILE" "$TARGET_FILE" > /dev/null 2>&1
        fi

        echo "Верстаю книгу с идеальными полями..."
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

        pdfjam --twoside \
            --trim '12mm 15mm 12mm 15mm' --clip true \
            --scale 1 \
            --offset '5mm 0mm' \
            --paper a5paper \
            "$TEMP_RAW" --outfile "$A5_OUTPUT"

        if [ "$EXTENSION" = "djvu" ]; then rm "$TEMP_RAW"; fi
        ;;
        
    *)
        echo "Ошибка: Формат не поддерживается."
        rm -f "$HEADER_TEX"
        exit 1
        ;;
esac

rm -f "$HEADER_TEX"

if [ -f "$A5_OUTPUT" ]; then
    echo "Создаю тетради для печати..."
    pdfbook2 --no-crop --signature=16 --short-edge \
        --inner-margin 0 --outer-margin 0 --top-margin 0 --bottom-margin 0 \
        "$A5_OUTPUT"
    
    if [ -f "${BASENAME}_A5-book.pdf" ]; then
        mv "${BASENAME}_A5-book.pdf" "$PRINT_OUTPUT"
        echo "ГОТОВО! ЭКРАН: $A5_OUTPUT | ПЕЧАТЬ: $PRINT_OUTPUT"
    fi
fi