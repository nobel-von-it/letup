#!/bin/bash

if ! command -v zed &> /dev/null && ! command -v zeditor &> /dev/null; then
    echo "Zed is not installed"
    echo "Use 'pcma' to do it"
    exit 1
fi

if [ -z "$1" ]; then
    echo "Usage: ./install-zed-ext.sh <ext-name>"
    exit 1
fi

EXT_NAME="$1"
ZED_DIR="$HOME/.local/share/zed/extensions"
INSTALL_DIR="$ZED_DIR/installed/$EXT_NAME"
TEMP_FILE="/tmp/${EXT_NAME}-zed-ext.tar.gz"
URL="https://api.zed.dev/extensions/$EXT_NAME/download"

PROXY_URL="${LOCAL_PROXY_URL:-socks5h://127.0.0.1:10808}"

clean_exit() {
    rm "$TEMP_FILE"
    exit 1
}

if pgrep -x "zed-editor|zeditor|zed" > /dev/null; then
    echo "Zed is running. Close!"
    echo "Enter to continue. Ctrl+C to exit"
    read
fi

echo "INSTALLING $EXT_NAME ($URL)..."

while true; do
    curl -L -C - --retry 3 --retry-delay 2 \
             -x "$PROXY_URL" \
             --user-agent "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36" \
             --output "$TEMP_FILE" "$URL"

    if [ $? -eq 0 ] || [ $? -eq 18 ]; then
        echo "Archive downloaded"
        break
    else
        echo "Recontecting..."
        sleep 1
    fi
done

if ! tar -tf "$TEMP_FILE" > /dev/null 2>&1; then
    echo "Archive validation error ($EXT_NAME)"
    echo "Try another extension name"

    clean_exit
fi

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

echo "CLEAN CACHE index.json"
if [ -f "$ZED_DIR/index.json" ]; then
    rm "$ZED_DIR/index.json"
    echo "Done!"
else
    echo "Not found"
fi

rm "$TEMP_FILE"
echo "INSTALLATION COMPLETED"
