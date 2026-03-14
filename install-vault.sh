#!/bin/bash
# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   echo "Запусти меня с sudo!" 
   exit 1
fi

# 1. Создаем директории и файлы
mkdir -p /usr/local/bin
cat <<EOF > /usr/local/bin/vault_mount.sh
#!/bin/bash
mkdir -p /mnt/vault
mount -o uid=1000,gid=1000,dmask=077,fmask=177 /dev/disk/by-uuid/$1 /mnt/vault
EOF
chmod +x /usr/local/bin/vault_mount.sh

cat <<EOF > /etc/systemd/system/vault-mount.service
[Unit]
Description=Auto-mount Secure Vault
After=systemd-udev-settle.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/vault_mount.sh $1
RemainAfterExit=yes
ExecStop=/usr/bin/umount /mnt/vault
EOF

cat <<EOF > /etc/udev/rules.d/99-secure-vault.rules
ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="$1", ENV{UDISKS_IGNORE}="1", TAG+="systemd", ENV{SYSTEMD_WANTS}="vault-mount.service"
ACTION=="remove", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="$1", RUN+="/usr/bin/systemctl stop vault-mount.service"
EOF

# 2. Применяем
systemctl daemon-reload
udevadm control --reload-rules
echo "Настройка завершена для UUID: $1"
