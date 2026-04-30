#!/bin/bash

# 1. Проверяем, есть ли GPG-ключ на флешке
GPG_DIR="/mnt/vault/.gnupg"
if [ ! -d "$GPG_DIR" ]; then
    echo "Ошибка: Сейф не найден в /mnt/vault. Сначала примонтируй его."
    exit 1
fi

# 2. Ищем ID твоего GPG-ключа (берем первый найденный)
GPG_KEY_ID=$(gpg --homedir "$GPG_DIR" --list-secret-keys --keyid-format=LONG | grep "^sec" | awk -F'/' '{print $2}' | cut -d' ' -f1 | head -n 1)

if [ -z "$GPG_KEY_ID" ]; then
    echo "GPG-ключ не найден. Сгенерируй его командой: gpg --full-generate-key"
    exit 1
fi

echo "Найден ключ GPG: $GPG_KEY_ID. Настраиваю Git..."

# 3. Применяем настройки Git
git config --global user.signingkey "$GPG_KEY_ID"
git config --global user.name "nobel-von-it"
git config --global user.email "maksimdavydenko12@gmail.com"
git config --global commit.gpgsign true
git config --global gpg.program gpg

# 4. Настройка SSH для Git (используем порт 443 для обхода блокировок порта 22)
git config --global core.sshCommand "ssh -o IdentitiesOnly=yes -i /mnt/vault/.ssh/id_ed25519"

echo "✅ Git успешно настроен для подписи коммитов ключом $GPG_KEY_ID"
