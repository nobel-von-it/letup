#!/bin/bash

# 1. Проверяем, есть ли локальные GPG-ключи
if [ ! -d "$HOME/.gnupg" ]; then
    echo "Ошибка: Локальная папка GPG (~/.gnupg) не найдена."
    exit 1
fi

# 2. Ищем ID локального GPG-ключа (берем первый найденный)
GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format=LONG | grep "^sec" | awk -F'/' '{print $2}' | cut -d' ' -f1 | head -n 1)

if [ -z "$GPG_KEY_ID" ]; then
    echo "GPG-ключ не найден в локальной связке. Сгенерируй его командой: gpg --full-generate-key"
    exit 1
fi

echo "Найден локальный ключ GPG: $GPG_KEY_ID. Настраиваю Git..."

# 3. Применяем настройки Git
git config --global user.signingkey "$GPG_KEY_ID"
git config --global user.name "nobel-von-it"
git config --global user.email "maksimdavydenko12@gmail.com"
git config --global commit.gpgsign true
git config --global gpg.program gpg

# 4. Настройка SSH для Git (используем локальный ключ)
if [ -f "$HOME/.ssh/id_ed25519" ]; then
    git config --global core.sshCommand "ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519"
    echo "✅ SSH-ключ для Git настроен: ~/.ssh/id_ed25519"
else
    echo "⚠️  Локальный SSH-ключ ~/.ssh/id_ed25519 не найден. Настройка core.sshCommand пропущена."
fi

echo "✅ Git успешно настроен для подписи коммитов локальным ключом $GPG_KEY_ID"
