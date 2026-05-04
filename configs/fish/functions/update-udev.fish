function update-udev
    sudo udevadm control --reload-rules
    sudo udevadm trigger
end

