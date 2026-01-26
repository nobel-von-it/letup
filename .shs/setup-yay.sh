#!/usr/bin/env bash

TARGET_DIR="$(realpath "$(dirname "$(realpath "$0")")/../yay")"

YAY_URL="https://aur.archlinux.org/yay.git"

if [ ! -d "$TARGET_DIR" ]; then
    git clone --depth=1 "$YAY_URL" "$TARGET_DIR"
    cd "$TARGET_DIR"
    makepkg -si
    cd -
else
    echo "yay is already installed"
fi
