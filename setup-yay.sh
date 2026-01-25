#!/usr/bin/env bash

TARGET_DIR="$(dirname "$(realpath "$0")")/../yay"

YAY_URL="https://aur.archlinux.org/yay.git"

if [ ! -d "$TARGET_DIR" ]; then
    git clone --depth=1 "$YAY_URL" "$TARGET_DIR"
    cd "$TARGET_DIR" || exit 1
    makepkg -si
    cd ..
else
    echo "yay is already installed"
fi
