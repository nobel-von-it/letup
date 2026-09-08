#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
REQ_FILE="$SCRIPT_DIR/requirements.txt"

echo "=========================================================="
echo "    Aeon Parser & Booker Dependencies Installer"
echo "=========================================================="

# 1. Detect Package Manager and Distro
if command -v pacman &>/dev/null; then
    echo "[*] Обнаружен дистрибутив на базе Arch Linux (pacman)"
    echo "[*] Обновление базы пакетов и установка системных утилит..."
    sudo pacman -Sy --needed --noconfirm \
        python python-pip python-virtualenv \
        pandoc typst texlive-binextra pdfbook2 calibre curl

elif command -v apt &>/dev/null; then
    echo "[*] Обнаружен дистрибутив Pop!_OS / Ubuntu / Debian (apt)"
    echo "[*] Обновление репозиториев и установка системных утилит..."
    sudo apt update
    sudo apt install -y \
        python3 python3-pip python3-venv \
        pandoc texlive-extra-utils calibre curl

    # Check / Install Typst on Pop!_OS / Ubuntu if not available in apt
    if ! command -v typst &>/dev/null; then
        if apt-cache show typst &>/dev/null 2>&1; then
            sudo apt install -y typst
        else
            echo "[*] Typst отсутствует в стандартном репозитории apt, устанавливаю официальный бинарник..."
            ARCH=$(uname -m)
            # TODO: Check latest version on github repo
            TYPST_VERSION="v0.15.1"
            if [ "$ARCH" = "x86_64" ]; then
                TYPST_ARCH="x86_64-unknown-linux-musl"
            elif [ "$ARCH" = "aarch64" ]; then
                TYPST_ARCH="aarch64-unknown-linux-musl"
            else
                TYPST_ARCH="x86_64-unknown-linux-musl"
            fi
            TEMP_TYPST=$(mktemp -d)
            curl -fsSL "https://github.com/typst/typst/releases/download/${TYPST_VERSION}/typst-${TYPST_ARCH}.tar.xz" -o "$TEMP_TYPST/typst.tar.xz"
            tar -xf "$TEMP_TYPST/typst.tar.xz" -C "$TEMP_TYPST"
            sudo cp "$TEMP_TYPST/typst-${TYPST_ARCH}/typst" /usr/local/bin/typst
            sudo chmod +x /usr/local/bin/typst
            rm -rf "$TEMP_TYPST"
            echo "[+] Typst успешно установлен в /usr/local/bin/typst"
        fi
    fi
else
    echo "[-] Ошибка: Поддерживаются только Arch Linux (pacman) и Pop!_OS / Ubuntu / Debian (apt)."
    exit 1
fi

# 2. Setup Python Virtual Environment
echo ""
echo "[*] Настройка Python venv в $VENV_DIR..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi

echo "[*] Установка зависимостей Python..."
"$VENV_DIR/bin/pip" install --upgrade pip
if [ -f "$REQ_FILE" ]; then
    "$VENV_DIR/bin/pip" install -r "$REQ_FILE"
else
    "$VENV_DIR/bin/pip" install beautifulsoup4 requests lxml
fi

echo ""
echo "=========================================================="
echo " [✓] Установка успешно завершена!"
echo " Проверка установленных утилит:"
echo " - python:  $(command -v python3 || echo 'не найден')"
echo " - pandoc:  $(command -v pandoc || echo 'не найден')"
echo " - typst:   $(command -v typst || echo 'не найден')"
echo " - pdfjam:  $(command -v pdfjam || echo 'не найден')"
echo " - venv:    $VENV_DIR"
echo "=========================================================="
echo "Теперь вы можете запускать:"
echo "  ./aeon-parser/main.py <URL>"
echo "или"
echo "  ./booker.sh <файл.epub | файл.md>"
echo "=========================================================="
