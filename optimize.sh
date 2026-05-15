#!/bin/bash

# Laptop Optimization Script for Arch Linux (Intel + Niri)
# Focus: power-profiles-daemon, thermald, powertop, Intel Xe GPU power saving

set -e

echo "--- Starting Arch Linux Laptop Optimization ---"

# 1. Check for root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

# 2. Install necessary packages
echo "[*] Installing packages..."
pacman -S --needed --noconfirm power-profiles-daemon thermald powertop swayidle python-gobject

# 3. Disable conflicting services
echo "[*] Checking for conflicting services (TLP, auto-cpufreq)..."
for service in tlp auto-cpufreq; do
    if systemctl is-active --quiet $service; then
        echo "[-] Disabling $service to avoid conflicts with power-profiles-daemon..."
        systemctl disable --now $service
    fi
done

# 4. Enable core services
echo "[*] Enabling power-profiles-daemon and thermald..."
systemctl enable --now power-profiles-daemon
systemctl enable --now thermald

# 5. Set default power profile
echo "[*] Setting power-profiles-daemon to 'power-saver'..."
powerprofilesctl set power-saver

# 6. Configure Powertop Auto-tune Service
echo "[*] Configuring Powertop auto-tune service..."
cat <<EOF > /etc/systemd/system/powertop-autotune.service
[Unit]
Description=Powertop tunings
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/powertop --auto-tune
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now powertop-autotune.service

# 7. Intel Xe GPU Power Saving (SLPC)
# Modern kernels (6.11+) support slpc_power_profile
echo "[*] Configuring Intel GPU power saving (Xe driver)..."
UDEV_RULE="/etc/udev/rules.d/60-intel-gpu-power.rules"
echo 'ACTION=="add", SUBSYSTEM=="drm", KERNEL=="card*", ATTR{device/slpc_power_profile}="power_saving"' > "$UDEV_RULE"
echo "[+] Created udev rule: $UDEV_RULE"

# Apply it immediately if the file exists
GPU_PATH="/sys/class/drm/card0/device/slpc_power_profile"
if [ -f "$GPU_PATH" ]; then
    echo "power_saving" > "$GPU_PATH" || echo "Note: Could not set GPU profile immediately (requires newer kernel?)"
fi

# 8. Kernel Parameters for Intel GPU (Xe over i915)
echo "[*] Configuring kernel parameters for Intel GPU..."
CMDLINE_FILE="/etc/kernel/cmdline"
if [ -f "$CMDLINE_FILE" ]; then
    CURRENT_CMDLINE=$(cat "$CMDLINE_FILE")
    NEW_CMDLINE="$CURRENT_CMDLINE"
    
    if [[ ! "$CURRENT_CMDLINE" =~ "i915.force_probe=!4628" ]]; then
        NEW_CMDLINE="$NEW_CMDLINE i915.force_probe=!4628"
    fi
    if [[ ! "$CURRENT_CMDLINE" =~ "xe.force_probe=4628" ]]; then
        NEW_CMDLINE="$NEW_CMDLINE xe.force_probe=4628"
    fi
    
    if [ "$CURRENT_CMDLINE" != "$NEW_CMDLINE" ]; then
        echo "$NEW_CMDLINE" > "$CMDLINE_FILE"
        echo "[+] Updated $CMDLINE_FILE"
    fi
else
    echo "Note: $CMDLINE_FILE not found. Skipping kernel parameter configuration."
fi

# 9. mkinitcpio Configuration (Early KMS)
echo "[*] Configuring mkinitcpio MODULES..."
MKINITCPIO_CONF="/etc/mkinitcpio.conf"

add_module() {
    local mod=$1
    local file=$2
    if grep -q "^MODULES=" "$file"; then
        if ! grep -q "^MODULES=(.*\<${mod}\>.*)" "$file"; then
            echo "[+] Adding $mod to mkinitcpio MODULES"
            sed -i "s/^MODULES=(\(.*\))/MODULES=(\1 ${mod})/" "$file"
            return 0
        fi
    fi
    return 1
}

M_CHANGED=0
if [ -f "$MKINITCPIO_CONF" ]; then
    add_module "xe" "$MKINITCPIO_CONF" && M_CHANGED=1
    add_module "i915" "$MKINITCPIO_CONF" && M_CHANGED=1
    
    if [ $M_CHANGED -eq 1 ]; then
        echo "[*] Rebuilding initramfs..."
        mkinitcpio -P
    fi
else
    echo "Note: $MKINITCPIO_CONF not found. Skipping mkinitcpio configuration."
fi

echo "--- Optimization Complete ---"
echo ""
echo "Additional Manual Steps:"
echo "1. Niri Config: Add 'swayidle' to your startup. Example:"
echo "   spawn-at-startup \"swayidle -w timeout 300 'niri msg action power-off-monitors' resume 'niri msg action power-on-monitors'\""
echo "2. Reboot is recommended to ensure all udev rules and services are fully applied."

