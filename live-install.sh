#!/bin/bash

# --- Configuration ---
DISK="/dev/nvme0n1"
HOSTNAME="arch-niri"
USERNAME="username"
TIMEZONE="Europe/Moscow"
LOCALE="en_US.UTF-8"

# Detect partition naming (p1 for nvme/loop/mmcblk, 1 for sdX/vdX)
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

for arg in "$@"; do
    case $arg in
        --min) MIN_INSTALL=true ;;
        --confirm) CONFIRM=true ;;
        --mskip) SKIP_MIRRORS=true ;;
    esac
done

set -e # Exit on error

echo "--- Arch Linux Live CD Installer ---"

# --- Functions ---

optimize_pacman() {
    echo "--- Optimizing Pacman for Live CD ---"
    # Force enable parallel downloads with 10 threads
    sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf
    
    # Set Russian mirrors (only for Live CD environment)
    if [ "$SKIP_MIRRORS" = false ]; then
        if command -v reflector >/dev/null 2>&1; then
            echo "Updating mirrorlist (Russia)..."
            reflector --country Russia --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
        fi
    else
        echo "Skipping mirrorlist update as requested."
    fi
}

setup_partitions() {
    echo "--- Partitioning $DISK ---"
    if [ "$IS_EFI" = true ]; then
        # UEFI: EFI (1G) + Root
        sfdisk "$DISK" <<EOF
label: gpt
1 : start=2048, size=2097152, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
2 : start=2099200, type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709
EOF
    else
        # BIOS: BIOS Boot (1M) + Root
        sfdisk "$DISK" <<EOF
label: gpt
1 : start=2048, size=2048, type=21686148-6449-6E6F-744E-656564454649
2 : start=4096, type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709
EOF
    fi
}

format_and_mount() {
    echo "--- Formatting and Mounting ---"
    
    # Wait for partitions to be recognized
    echo "Waiting for kernel to re-read partition table..."
    udevadm settle
    sleep 2

    # Wipe old signatures to avoid mount confusion
    wipefs -a "$PART_ROOT" || true
    
    if [ "$IS_EFI" = true ]; then
        wipefs -a "$PART_BOOT" || true
        mkfs.fat -F32 "$PART_BOOT"
        mkfs.btrfs -f "$PART_ROOT"
        mount "$PART_ROOT" /mnt
        mount --mkdir "$PART_BOOT" /mnt/boot
    else
        # In BIOS mode, PART_BOOT is the BIOS Boot partition (no FS needed)
        # We only format Root
        mkfs.btrfs -f "$PART_ROOT"
        mount "$PART_ROOT" /mnt
    fi
}

install_base() {
    echo "--- Pacstrap (Base System) ---"
    PACKAGES="base linux linux-headers base-devel neovim git networkmanager btrfs-progs"
    
    if [ "$MIN_INSTALL" = false ]; then
        PACKAGES="$PACKAGES linux-firmware amd-ucode"
    fi

    pacstrap -K /mnt $PACKAGES
}

generate_fstab() {
    echo "--- Generating fstab ---"
    genfstab -U /mnt >> /mnt/etc/fstab
}

configure_system() {
    echo "--- Configuring System (Chroot) ---"
    
    # We'll create a small helper script to run inside chroot
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
# Mirrorlist is NOT touched here as requested.

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

    echo "Configuring systemd-boot entry..."
    OPTIONS="root=$PART_ROOT rw rootfstype=btrfs"
    if [ "$MIN_INSTALL" = false ]; then
        OPTIONS="$OPTIONS nvidia_drm.modeset=1 nvidia_drm.fbdev=1"
    fi

    cat <<EOT > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
$( [ "$MIN_INSTALL" = false ] && echo "initrd  /amd-ucode.img" )
initrd  /initramfs-linux.img
options $OPTIONS
EOT

    echo "default arch.conf" > /boot/loader/loader.conf
    echo "timeout 3" >> /boot/loader/loader.conf
else
    echo "Installing Bootloader (GRUB for BIOS)..."
    pacman -S --noconfirm grub
    grub-install --target=i386-pc "$DISK"
    
    # Configure GRUB
    OPTIONS="nvidia_drm.modeset=1 nvidia_drm.fbdev=1"
    if [ "$MIN_INSTALL" = true ]; then OPTIONS=""; fi
    
    sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"quiet rw rootfstype=btrfs $OPTIONS\"|" /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg
fi

if [ "$MIN_INSTALL" = false ]; then
    echo "Installing NVIDIA and Desktop components..."
    pacman -S --noconfirm nvidia-dkms nvidia-utils egl-wayland \
        niri xdg-desktop-portal-gnome polkit-gnome qt5-wayland qt6-wayland \
        alacritty waybar fuzzel mako swaybg greetd greetd-tuigreet \
        nwg-look kvantum

    echo "Configuring NVIDIA Early KMS..."
    sed -i 's/^MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    # Remove kms hook if present
    sed -i 's/ kms / /' /etc/mkinitcpio.conf
    mkinitcpio -P

    echo "Enabling NVIDIA power management services..."
    systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service

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
    echo "Usage: $0 --confirm [--min] [--mskip]"
    exit 1
fi

optimize_pacman
setup_partitions
format_and_mount
install_base
generate_fstab
configure_system

echo "--- INSTALLATION COMPLETE ---"
echo "You can now reboot into your new Arch Linux system."
