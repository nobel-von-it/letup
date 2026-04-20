#!/bin/bash

sudo apt update
sudo apt install -y ripgrep rustup fish eza pkg-config libssl-dev bpytop ffmpeg syncthing

rustup default stable

cargo install --locked typst-cli du-dust

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | \
  sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg
echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | \
  sudo tee /etc/apt/sources.list.d/antigravity.list > /dev/null

sudo apt update
sudo apt install -y antigravity

systemctl --user enable --now syncthing.service

chsh
