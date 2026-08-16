#!/bin/bash

echo "Applying USB autosuspend and Audio hotplug fixes..."

# 1. Create unified udev rules for mouse and keyboard
cat << 'EOF' > /tmp/99-input-autosuspend.rules
# UGREEN Mouse
ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="2b89", ATTR{idProduct}=="0043", ATTR{power/control}="on", RUN+="/usr/bin/sh -c 'echo on > /sys$env{DEVPATH}/power/control'"

# foostan Corne v4 Keyboard
ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="4653", ATTR{idProduct}=="0004", ATTR{power/control}="on", RUN+="/usr/bin/sh -c 'echo on > /sys$env{DEVPATH}/power/control'"
EOF

sudo mv /tmp/99-input-autosuspend.rules /etc/udev/rules.d/99-input-autosuspend.rules
if [ -f /etc/udev/rules.d/99-ugreen-mouse.rules ]; then
    echo "Backing up old mouse rules..."
    sudo mv /etc/udev/rules.d/99-ugreen-mouse.rules /etc/udev/rules.d/99-ugreen-mouse.rules.bak
fi

# 2. Reload and trigger udev rules
echo "Reloading udev rules..."
sudo udevadm control --reload-rules
sudo udevadm trigger

# 3. Create modprobe config for snd-hda-intel to disable power_save
cat << 'EOF' > /tmp/snd-hda-intel.conf
options snd-hda-intel power_save=0 power_save_controller=N
EOF
sudo mv /tmp/snd-hda-intel.conf /etc/modprobe.d/snd-hda-intel.conf

# 4. Create systemd override for powertop-autotune to prevent it from enabling audio power saving
sudo mkdir -p /etc/systemd/system/powertop-autotune.service.d
cat << 'EOF' > /tmp/override.conf
[Service]
ExecStartPost=/usr/bin/sh -c "echo 0 > /sys/module/snd_hda_intel/parameters/power_save"
ExecStartPost=/usr/bin/sh -c "echo N > /sys/module/snd_hda_intel/parameters/power_save_controller"
EOF
sudo mv /tmp/override.conf /etc/systemd/system/powertop-autotune.service.d/override.conf

# 5. Reload systemd daemon and restart powertop-autotune
echo "Reloading systemd and restarting powertop-autotune..."
sudo systemctl daemon-reload
sudo systemctl restart powertop-autotune.service

# 6. Apply audio changes immediately to the running kernel
echo "Disabling audio power saving in running kernel..."
echo 0 | sudo tee /sys/module/snd_hda_intel/parameters/power_save > /dev/null
echo N | sudo tee /sys/module/snd_hda_intel/parameters/power_save_controller > /dev/null

echo "Fixes applied successfully!"
