#!/bin/bash

LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

install -D -m 755 $(realpath "./pcma") "$LOCAL_BIN"

add_export_path() {
    local shell=$(basename "$SHELL")
    case "$shell" in
        bash)
            echo "export PATH=$HOME/.local/bin:$PATH" >> $HOME/.bashrc
            ;;
        zsh)
            echo "export PATH=$HOME/.local/bin:$PATH" >> $HOME/.bashrc
            ;;
        *)
            echo "Shell is not supported"
            ;;
    esac
}

if command -v pcma &> /dev/null; then
    echo "Done!"
else

fi
