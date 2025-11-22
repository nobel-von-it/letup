function get_touch_id
    xinput --list | grep -i touchpad | awk '{ split($3, res, " "); split(res[3], id, "="); print id[2] }'
end
