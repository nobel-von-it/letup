#!/bin/bash
# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   echo "Запусти меня с sudo!" 
   exit 1
fi

if [[ -z "$1" ]]; then
   echo "Использование: sudo ./install_vault.sh <UUID_ФЛЕШКИ>"
   exit 1
fi

UUID=$1

# 1. Удаляем старые файлы, если они есть (очистка)
rm -f /usr/local/bin/vault_mount.sh
rm -f /etc/systemd/system/vault-mount.service
rm -f /etc/udev/rules.d/99-secure-vault.rules

# 2. Создаем новые файлы
mkdir -p /usr/local/bin

# Скрипт монтирования
cat <<EOF > /usr/local/bin/vault_mount.sh
#!/bin/bash
mkdir -p /mnt/vault
mount /dev/disk/by-uuid/$UUID /mnt/vault
EOF
chmod +x /usr/local/bin/vault_mount.sh

# Сервис systemd
cat <<EOF > /etc/systemd/system/vault-mount.service
[Unit]
Description=Auto-mount Secure Vault (ext4)
After=systemd-udev-settle.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/vault_mount.sh
RemainAfterExit=yes
ExecStop=/usr/bin/umount /mnt/vault
EOF

# Udev правило
cat <<EOF > /etc/udev/rules.d/99-secure-vault.rules
ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="$UUID", ENV{UDISKS_IGNORE}="1", TAG+="systemd", ENV{SYSTEMD_WANTS}="vault-mount.service"
ACTION=="remove", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="$UUID", RUN+="/usr/bin/systemctl stop vault-mount.service"
EOF

# 3. Применяем настройки
systemctl daemon-reload
udevadm control --reload-rules
echo "✅ Настройка обновлена для UUID: $UUID"
