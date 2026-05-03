#!/bin/bash

# --- Configuration ---
DISK="/dev/nvme0n1"
HOSTNAME="arch-niri"
USERNAME="username" # Change this or it will be prompted
TIMEZONE="Europe/Moscow"
LOCALE="en_US.UTF-8"

set -e # Exit on error

echo "--- Arch Linux Live CD Installer ---"

# --- Functions ---

setup_partitions() {
    echo "--- Partitioning $DISK ---"
    # Create a 1GB EFI partition and use the rest for Root
    # 2048 is the start sector for alignment
    # +1G is the size of the first partition
    # type 1 is EFI
    # type 20 is Linux Root (x86-64)
    sfdisk "$DISK" <<EOF
label: gpt
device: $DISK
unit: sectors

$DISK-p1 : start=2048, size=2097152, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
$DISK-p2 : start=2099200, type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709
EOF
}

format_and_mount() {
    echo "--- Formatting and Mounting ---"
    mkfs.fat -F32 "${DISK}p1"
    mkfs.btrfs -f "${DISK}p2"
    
    mount "${DISK}p2" /mnt
    mount --mkdir "${DISK}p1" /mnt/boot
}

install_base() {
    echo "--- Pacstrap (Base System + Drivers) ---"
    # Essential packages + user requested
    pacstrap -K /mnt base linux linux-headers linux-firmware amd-ucode base-devel neovim git networkmanager btrfs-progs
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

echo "Setting up network..."
systemctl enable NetworkManager

echo "Setting up user: $USERNAME..."
useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "Set password for $USERNAME:"
passwd "$USERNAME"
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "Installing Bootloader (systemd-boot)..."
bootctl install

echo "Configuring systemd-boot entry..."
cat <<EOT > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /amd-ucode.img
initrd  /initramfs-linux.img
options root=${DISK}p2 rw rootfstype=btrfs nvidia_drm.modeset=1 nvidia_drm.fbdev=1
EOT

echo "default arch.conf" > /boot/loader/loader.conf
echo "timeout 3" >> /boot/loader/loader.conf

echo "Installing NVIDIA and Desktop components..."
pacman -S --noconfirm nvidia-dkms nvidia-utils egl-wayland \
    niri xdg-desktop-portal-gnome polkit-gnome qt5-wayland qt6-wayland \
    alacritty waybar fuzzel mako swaybg greetd tuigreet \
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

echo "Done inside chroot!"
EOF

    chmod +x /mnt/setup-chroot.sh
    arch-chroot /mnt /setup-chroot.sh
    rm /mnt/setup-chroot.sh
}

# --- Main Execution ---

if [[ $1 != "--confirm" ]]; then
    echo "WARNING: This will WIPE $DISK."
    echo "Run with --confirm to proceed."
    exit 1
fi

setup_partitions
format_and_mount
install_base
generate_fstab
configure_system

echo "--- INSTALLATION COMPLETE ---"
echo "You can now reboot into your new Arch Linux system."
