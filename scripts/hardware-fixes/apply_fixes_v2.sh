#!/bin/bash

echo "Applying safe USB autosuspend and Audio hotplug fixes..."

# 1. Create clean udev rules without RUN loop to avoid overloading udev
cat << 'EOF' > /tmp/99-input-autosuspend.rules
# UGREEN Mouse
ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="2b89", ATTR{idProduct}=="0043", ATTR{power/control}!="on", ATTR{power/control}="on"

# foostan Corne v4 Keyboard
ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="4653", ATTR{idProduct}=="0004", ATTR{power/control}!="on", ATTR{power/control}="on"
EOF

sudo mv /tmp/99-input-autosuspend.rules /etc/udev/rules.d/99-input-autosuspend.rules

# 2. Reload and trigger udev rules
echo "Reloading udev rules..."
sudo udevadm control --reload-rules
sudo udevadm trigger

# 3. Create modprobe config for snd-hda-intel to disable power_save
cat << 'EOF' > /tmp/snd-hda-intel.conf
options snd-hda-intel power_save=0 power_save_controller=N
EOF
sudo mv /tmp/snd-hda-intel.conf /etc/modprobe.d/snd-hda-intel.conf

# 4. Create systemd override for powertop-autotune to disable autosuspend for mouse, keyboard, and audio
sudo mkdir -p /etc/systemd/system/powertop-autotune.service.d
cat << 'EOF' > /tmp/override.conf
[Service]
# Disable audio power saving after powertop runs
ExecStartPost=/usr/bin/sh -c "echo 0 > /sys/module/snd_hda_intel/parameters/power_save"
ExecStartPost=/usr/bin/sh -c "echo N > /sys/module/snd_hda_intel/parameters/power_save_controller"

# Disable USB autosuspend for keyboard (4653:0004) and mouse (2b89:0043) after powertop runs
ExecStartPost=/usr/bin/bash -c 'for d in /sys/bus/usb/devices/*; do if [ -f "$d/idVendor" ]; then vid=$(cat "$d/idVendor" 2>/dev/null); pid=$(cat "$d/idProduct" 2>/dev/null); if [ "$vid" = "2b89" -a "$pid" = "0043" ] || [ "$vid" = "4653" -a "$pid" = "0004" ]; then echo on > "$d/power/control"; fi; fi; done'
EOF
sudo mv /tmp/override.conf /etc/systemd/system/powertop-autotune.service.d/override.conf

# 5. Reload systemd daemon and restart powertop-autotune
echo "Reloading systemd and restarting powertop-autotune..."
sudo systemctl daemon-reload
sudo systemctl restart powertop-autotune.service

# 6. Apply all changes immediately to the running kernel
echo "Applying changes immediately..."
echo 0 | sudo tee /sys/module/snd_hda_intel/parameters/power_save > /dev/null
echo N | sudo tee /sys/module/snd_hda_intel/parameters/power_save_controller > /dev/null

# Force 'on' for keyboard and mouse right now
for d in /sys/bus/usb/devices/*; do
    if [ -f "$d/idVendor" ]; then
        vid=$(cat "$d/idVendor" 2>/dev/null)
        pid=$(cat "$d/idProduct" 2>/dev/null)
        if [ "$vid" = "2b89" -a "$pid" = "0043" ] || [ "$vid" = "4653" -a "$pid" = "0004" ]; then
            echo on | sudo tee "$d/power/control" > /dev/null
        fi
    fi
done

echo "Fixes applied successfully!"
