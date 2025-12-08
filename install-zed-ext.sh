#!/bin/bash

# Verify Zed is installed
if ! command -v zed &> /dev/null && ! command -v zeditor &> /dev/null; then
    echo "Zed is not installed"
    echo "Use 'pcma' to do it"
    exit 1
fi

# Check argument
if [ -z "$1" ]; then
    echo "Usage: ./install-zed-ext.sh <ext-name>"
    exit 1
fi

EXT_NAME="$1"
ZED_DIR="$HOME/.local/share/zed/extensions"
INSTALL_DIR="$ZED_DIR/installed/$EXT_NAME"
TEMP_FILE="/tmp/${EXT_NAME}-zed-ext.tar.gz"
URL="https://api.zed.dev/extensions/$EXT_NAME/download"

clean_exit() {
    rm -f "$TEMP_FILE"
    exit 1
}

# Ensure Zed isn't running
if pgrep -x "zed-editor|zeditor|zed" > /dev/null; then
    echo "Zed is running. Close!"
    echo "Enter to continue. Ctrl+C to exit"
    read
fi

echo "INSTALLING $EXT_NAME ($URL)..."

# Robust download loop with wget
while true; do
    wget --continue \
         --tries=5 \
         --retry-connrefused \
         --waitretry=2 \
         --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36" \
         -O "$TEMP_FILE" "$URL"

    rc=$?
    if [ $rc -eq 0 ]; then
        echo "Archive downloaded"
        break
    elif [ $rc -eq 4 ]; then
        echo "Connection error, retrying..."
        sleep 1
    else
        echo "Download failed with exit code $rc"
        clean_exit
    fi
done

# Validate archive
if ! tar -tf "$TEMP_FILE" > /dev/null 2>&1; then
    echo "Archive validation error ($EXT_NAME)"
    echo "Try another extension name"
    clean_exit
fi

# Install extension
echo "UNPACKING '$TEMP_FILE' to '$INSTALL_DIR'"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

tar -xzf "$TEMP_FILE" -C "$INSTALL_DIR"
if [ $? -eq 0 ]; then
    echo "Done!"
else
    echo "unpacking error"
    clean_exit
fi

# Clean up
echo "CLEAN CACHE index.json"
if [ -f "$ZED_DIR/index.json" ]; then
    rm "$ZED_DIR/index.json"
    echo "Done!"
else
    echo "Not found"
fi

rm -f "$TEMP_FILE"
echo "INSTALLATION COMPLETED"
