#!/bin/bash

# --- Configuration ---
DISK="/dev/nvme0n1"
HOSTNAME="arch-niri"
USERNAME="username"
TIMEZONE="Europe/Moscow"
LOCALE="en_US.UTF-8"

# Detect partition naming
if [[ $DISK == *nvme* || $DISK == *mmcblk* || $DISK == *loop* ]]; then
    P_SUFFIX="p"
else
    P_SUFFIX=""
fi

PART_BOOT="${DISK}${P_SUFFIX}1"
PART_ROOT="${DISK}${P_SUFFIX}2"

# Detect UEFI/BIOS
IS_EFI=false
if [ -d /sys/firmware/efi ]; then
    IS_EFI=true
fi

# Parse flags
MIN_INSTALL=false
CONFIRM=false
SKIP_MIRRORS=false
HW_PROFILE="amd-nvidia" # Default profile: amd-nvidia, intel-intel

for arg in "$@"; do
    case $arg in
        --min) MIN_INSTALL=true ;;
        --confirm) CONFIRM=true ;;
        --mskip) SKIP_MIRRORS=true ;;
        --profile=*) HW_PROFILE="${arg#*=}" ;;
    esac
done

set -e # Exit on error

echo "--- Arch Linux Live CD Installer ---"
echo "Hardware Profile: $HW_PROFILE"

# --- Functions ---

optimize_pacman() {
    echo "--- Optimizing Pacman for Live CD ---"
    sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf
    
    if [ "$SKIP_MIRRORS" = false ]; then
        if command -v reflector >/dev/null 2>&1; then
            echo "Updating mirrorlist (Russia)..."
            reflector --country Russia --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
        fi
    fi
}

setup_partitions() {
    echo "--- Partitioning $DISK ---"
    if [ "$IS_EFI" = true ]; then
        sfdisk "$DISK" <<EOF
label: gpt
1 : start=2048, size=2097152, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
2 : start=2099200, type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709
EOF
    else
        sfdisk "$DISK" <<EOF
label: gpt
1 : start=2048, size=2048, type=21686148-6449-6E6F-744E-656564454649
2 : start=4096, type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709
EOF
    fi
}

format_and_mount() {
    echo "--- Formatting and Mounting ---"
    udevadm settle
    sleep 2

    wipefs -a "$PART_ROOT" || true
    
    if [ "$IS_EFI" = true ]; then
        wipefs -a "$PART_BOOT" || true
        mkfs.fat -F32 "$PART_BOOT"
        mkfs.btrfs -f "$PART_ROOT"
        mount -t btrfs "$PART_ROOT" /mnt
        mount -t vfat --mkdir "$PART_BOOT" /mnt/boot
    else
        mkfs.btrfs -f "$PART_ROOT"
        mount -t btrfs "$PART_ROOT" /mnt
    fi
}

install_base() {
    echo "--- Pacstrap (Base System) ---"
    PACKAGES="base linux linux-headers base-devel neovim git networkmanager btrfs-progs"
    
    if [ "$MIN_INSTALL" = false ]; then
        PACKAGES="$PACKAGES linux-firmware"
        
        # Microcode selection based on profile
        if [ "$HW_PROFILE" = "amd-nvidia" ]; then
            PACKAGES="$PACKAGES amd-ucode"
        elif [ "$HW_PROFILE" = "intel-intel" ]; then
            PACKAGES="$PACKAGES intel-ucode"
        fi
    fi

    pacstrap -K /mnt $PACKAGES
}

generate_fstab() {
    echo "--- Generating fstab ---"
    genfstab -U /mnt >> /mnt/etc/fstab
}

configure_system() {
    echo "--- Configuring System (Chroot) ---"
    
    # Get Root UUID safely for bootloader configuration
    ROOT_UUID=$(blkid -s UUID -o value "$PART_ROOT")

    cat <<EOF > /mnt/setup-chroot.sh
#!/bin/bash
set -e

echo "Setting timezone and locale..."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname

echo "Optimizing Pacman in target system..."
sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf

echo "Setting up network..."
systemctl enable NetworkManager

echo "Setting up user: $USERNAME..."
useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "Set password for $USERNAME:"
passwd "$USERNAME"
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

if [ "$IS_EFI" = true ]; then
    echo "Installing Bootloader (systemd-boot)..."
    bootctl install

    # Base options using UUID
    OPTIONS="root=UUID=$ROOT_UUID rw rootfstype=btrfs"
    
    if [ "$MIN_INSTALL" = false ] && [ "$HW_PROFILE" = "amd-nvidia" ]; then
        OPTIONS="\$OPTIONS nvidia_drm.modeset=1 nvidia_drm.fbdev=1"
    fi
    # Note: Intel typically doesn't need extra kernel params for Wayland, i915 handles it.

    UCODE_IMG=""
    if [ "$MIN_INSTALL" = false ]; then
        if [ "$HW_PROFILE" = "amd-nvidia" ]; then
            UCODE_IMG="initrd  /amd-ucode.img"
        elif [ "$HW_PROFILE" = "intel-intel" ]; then
            UCODE_IMG="initrd  /intel-ucode.img"
        fi
    fi

    cat <<EOT > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
\$UCODE_IMG
initrd  /initramfs-linux.img
options \$OPTIONS
EOT

    echo "default arch.conf" > /boot/loader/loader.conf
    echo "timeout 3" >> /boot/loader/loader.conf
else
    echo "Installing Bootloader (GRUB for BIOS)..."
    pacman -S --noconfirm grub
    grub-install --target=i386-pc "$DISK"
    
    OPTIONS=""
    if [ "$MIN_INSTALL" = false ] && [ "$HW_PROFILE" = "amd-nvidia" ]; then 
        OPTIONS="nvidia_drm.modeset=1 nvidia_drm.fbdev=1"
    fi
    
    sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"quiet rw rootfstype=btrfs \$OPTIONS\"|" /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg
fi

if [ "$MIN_INSTALL" = false ]; then
    echo "Installing Desktop components (Niri)..."
    # Base GUI packages
    GUI_PACKAGES="niri xdg-desktop-portal-gnome polkit-gnome qt5-wayland qt6-wayland alacritty waybar fuzzel mako swaybg greetd greetd-tuigreet nwg-look kvantum"
    
    if [ "$HW_PROFILE" = "amd-nvidia" ]; then
        echo "Installing NVIDIA specific packages..."
        pacman -S --noconfirm nvidia-dkms nvidia-utils egl-wayland \$GUI_PACKAGES

        echo "Configuring NVIDIA Early KMS..."
        sed -i 's/^MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
        sed -i 's/ kms / /' /etc/mkinitcpio.conf # Remove kms hook for nvidia

        echo "Enabling NVIDIA power management services..."
        systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service

    elif [ "$HW_PROFILE" = "intel-intel" ]; then
        echo "Installing Intel specific packages..."
        pacman -S --noconfirm mesa vulkan-intel intel-media-driver \$GUI_PACKAGES

        echo "Configuring Intel Early KMS..."
        sed -i 's/^MODULES=()/MODULES=(i915)/' /etc/mkinitcpio.conf
        # We DO NOT remove the kms hook here, it is essential for Intel!
    fi

    # Rebuild initramfs after module changes
    mkinitcpio -P

    echo "Configuring greetd with tuigreet..."
    mkdir -p /etc/greetd
    cat <<EOT > /etc/greetd/config.toml
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --cmd niri-session"
user = "greeter"
EOT
    systemctl enable greetd
fi

echo "Done inside chroot!"
EOF

    chmod +x /mnt/setup-chroot.sh
    arch-chroot /mnt /setup-chroot.sh
    rm /mnt/setup-chroot.sh
}

# --- Main Execution ---

if [ "$CONFIRM" = false ]; then
    echo "WARNING: This will WIPE $DISK."
    echo "Usage: $0 --confirm [--min] [--mskip] [--profile=amd-nvidia|intel-intel]"
    exit 1
fi

optimize_pacman
setup_partitions
format_and_mount
install_base
generate_fstab
configure_system

echo "--- INSTALLATION COMPLETE ---"
echo "Profile: $HW_PROFILE. You can now reboot into your new Arch Linux system."