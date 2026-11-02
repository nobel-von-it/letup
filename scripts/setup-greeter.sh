#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LETUP_DIR="$(dirname "$SCRIPT_DIR")"
GREETD_SRC="$LETUP_DIR/configs/greetd"
GREETD_DEST="/etc/greetd"

echo "==> Настройка greetd + ReGreet из letup..."

if command -v pacman &>/dev/null; then
    MISSING_PKGS=()
    for pkg in greetd greetd-regreet; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            MISSING_PKGS+=("$pkg")
        fi
    done

    if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
        echo "Устанавливаем недостающие пакеты: ${MISSING_PKGS[*]}..."
        sudo pacman -S --needed "${MISSING_PKGS[@]}"
    fi
fi

sudo mkdir -p "$GREETD_DEST"

echo "==> Создаем символические ссылки из $GREETD_SRC в $GREETD_DEST..."

if [ -f "$GREETD_SRC/config.toml" ]; then
    sudo ln -sf "$GREETD_SRC/config.toml" "$GREETD_DEST/config.toml"
    echo "  [+] config.toml linked"
else
    echo "  [!] Предупреждение: $GREETD_SRC/config.toml не найден"
fi

if [ -f "$GREETD_SRC/regreet.toml" ]; then
    sudo ln -sf "$GREETD_SRC/regreet.toml" "$GREETD_DEST/regreet.toml"
    echo "  [+] regreet.toml linked"
fi

if [ -f "$GREETD_SRC/regreet.css" ]; then
    sudo ln -sf "$GREETD_SRC/regreet.css" "$GREETD_DEST/regreet.css"
    echo "  [+] regreet.css linked"
fi

if id "greeter" &>/dev/null; then
    echo "==> Настройка прав пользователя greeter..."
    sudo usermod -aG video,input greeter
fi

echo "==> Активация greetd.service в systemd..."
sudo systemctl enable greetd.service

echo "==> Настройка завершена успешно!"
