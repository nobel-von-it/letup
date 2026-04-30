#!/bin/bash
# pinentry-fuzzel: GPG passphrase entry via fuzzel

# Ensure environment variables are set for Wayland
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export DISPLAY="${DISPLAY:-:0}"

echo "OK Pleased to meet you"
while read -r line; do
    if [[ $line == GETPIN* ]]; then
        pin=$(fuzzel -d --prompt "🔒 Passphrase: " --password --lines 0 --width 30)
        
        if [ -z "$pin" ]; then
            echo "ERR 83886179 cancelled"
        else
            echo "D $pin"
            echo "OK"
        fi
    elif [[ $line == BYE* ]]; then
        echo "OK"
        exit 0
    else
        echo "OK"
    fi
done
