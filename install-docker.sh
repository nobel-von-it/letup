#!/bin/bash
set -e

echo "📦 Обновление кэша пакетов и установка базовых зависимостей..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

echo "🔑 Добавление официального GPG ключа Docker..."
sudo mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "📄 Настройка репозитория Docker..."
# Извлекаем кодовое имя Ubuntu (например, jammy), на котором основана твоя версия Pop!_OS
source /etc/os-release
UBUNTU_CODENAME=${UBUNTU_CODENAME:-$VERSION_CODENAME}

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $UBUNTU_CODENAME stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "🐳 Установка Docker Engine и плагинов..."
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "⚙️ Настройка прав пользователя (чтобы использовать Docker без sudo)..."
if ! getent group docker > /dev/null; then
    sudo groupadd docker
fi
sudo usermod -aG docker $USER

echo "🚀 Настройка systemd сервисов..."
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
sudo systemctl start docker.service

echo "✅ Docker успешно установлен!"
echo "================================================================="
echo "⚠️ ВАЖНО: Чтобы изменения прав вступили в силу, тебе нужно обновить сессию пользователя."
echo "Выполни команду: su - \$USER"
echo "Или просто перезайди в систему (Log out -> Log in)."
echo "После этого проверь работоспособность: docker run hello-world"
echo "================================================================="