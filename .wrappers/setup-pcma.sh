#!/bin/bash

LOCAL_BIN="$HOME/.local/bin"

add_export_path() {
    local shell=$(basename "$SHELL")
    echo "Adding to $shell"
    case "$shell" in
    bash)
        local rc="$HOME/.bashrc"
        echo "export PATH=$HOME/.local/bin:$PATH" >>"$rc"
        source "$rc"
        ;;
    zsh)
        local rc="$HOME/.zshrc"
        echo "export PATH=$HOME/.local/bin:$PATH" >>"$rc"
        source "$rc"
        ;;
    *)
        echo "Shell is not supported"
        ;;
    esac
}

mkdir -p "$LOCAL_BIN"

install -D -m 755 $(realpath "./pcma") "$LOCAL_BIN"

if command -v pcma &>/dev/null; then
    echo "Done!"
else
    add_export_path
fi
