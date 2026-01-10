#!/bin/bash

TARGET_DIR="${POEM_PATH:-$HOME/Documents/Poems}"

mkdir -p "$TARGET_DIR"

FILE_NAME="Стих $(date +%Y-%m-%d).md"
FULL_PATH="$TARGET_DIR/$FILE_NAME"

$MO_EDITOR "$FULL_PATH"
