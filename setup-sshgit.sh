#!/bin/bash

DEMAIL="maksimdavydenko12@gmail.com"
DNAME="nobel-von-it"

read -p "EMAIL [$DEMAIL]: " IEMAIL
EMAIL=${IEMAIL:-$DEMAIL}

read -p "NAME [$DNAME]: " INAME
NAME=${INAME:-$DNAME}

echo "Creating ssh key for $NAME < $EMAIL >"

KEY_PATH="$HOME/.ssh/id_ed25519"

if [ -f "$KEY_PATH" ]; then
    echo "Key exist"
    read -p "Rewrite (y/N): " OVERWRITE
    if [[ "$OVERWRITE" != "y" && "$OVERWRITE" != "Y" ]]; then
        echo "Discard generation"
    else
        ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY_PATH"
    fi
else
    ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY_PATH"
fi

eval "$(ssh-agent -s)"
ssh-add "$KEY_PATH"

PUB_KEY=$(cat "$KEY_PATH.pub")

if command -v xclip &> /dev/null; then
    echo "$PUB_KEY" | xclip -selection clipboard
    echo "Pub key is copied (xclip)"
elif command -v wl-copy &> /dev/null; then
    echo "$PUB_KEY" | wl-copy
    echo "Pub key is copied (wl-copy)"
else
    echo "Do it yourself:"
    echo "$PUB_KEY"
fi

echo "Configuring git"

git config --global user.email $EMAIL
git config --global user.name $NAME

GITHUB_URL="https://github.com/settings/ssh/new"

if command -v firefox &> /dev/null; then
    echo "Open in firefox"
    firefox "$GITHUB_URL"
elif command -v chromium &> /dev/null; then
    echo "Open in chromium"
    chromium "$GITHUB_URL"
else
    echo "No browser found"
    echo "Open yourself: $GITHUB_URL"
fi

echo "Done!"
