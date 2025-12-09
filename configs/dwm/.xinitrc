#!/bin/sh

TPAD="$(xinput list | grep -i 'touchpad' | awk -F'id=' '{print $1}' | sed 's/.*↳ //;s/[[:space:]]*$//')"

xinput set-prop "$TPAD" "libinput Tapping Enabled" 1
xinput set-prop "$TPAD" "libinput Natural Scrolling Enabled" 1

setxkbmap -layout us,ru -option grp:win_space_toggle

slstatus &

exec dwm
