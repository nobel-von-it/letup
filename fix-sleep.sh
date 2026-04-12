#!/bin/bash
# Скрипт для исправления проблем со сном (AMD + NVIDIA + systemd-boot)
# Этот скрипт должен быть запущен с правами sudo/root

set -e

if [[ $EUID -ne 0 ]]; then
   echo "Ошибка: Этот скрипт должен быть запущен через sudo."
   exit 1
fi

echo "--- 1. Настройка параметров модуля NVIDIA ---"
mkdir -p /etc/modprobe.d
cat <<EOF > /etc/modprobe.d/nvidia.conf
# Фикс для сохранения видеопамяти при уходе в сон (нужно для Wayland)
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_TemporaryFilePath=/var/tmp
# Включение modesetting
options nvidia_drm modeset=1
EOF
echo "Создан файл /etc/modprobe.d/nvidia.conf"

echo "--- 2. Включение системных сервисов NVIDIA ---"
systemctl enable nvidia-suspend.service
systemctl enable nvidia-resume.service
systemctl enable nvidia-hibernate.service
echo "Сервисы NVIDIA включены."

echo "--- 3. Отключение источников мгновенного пробуждения (ACPI) ---"
# Мы отключаем XHC0 (USB контроллер), PTXH и мосты GPP, которые часто "будят" AMD системы
mkdir -p /etc/tmpfiles.d
cat <<EOF > /etc/tmpfiles.d/disable-wakeup.conf
# Тип  Путь                 Режим UID GID Возраст Аргумент
w /proc/acpi/wakeup - - - - XHC0
w /proc/acpi/wakeup - - - - PTXH
w /proc/acpi/wakeup - - - - GPP0
w /proc/acpi/wakeup - - - - GPP8
w /proc/acpi/wakeup - - - - GP12
w /proc/acpi/wakeup - - - - GP13
EOF
echo "Создан файл /etc/tmpfiles.d/disable-wakeup.conf (сохранится после перезагрузки)"

echo "--- 4. Применение настроек ACPI немедленно ---"
for dev in XHC0 PTXH GPP0 GPP8 GP12 GP13; do
    if grep -q "$dev.*enabled" /proc/acpi/wakeup; then
        echo "$dev" > /proc/acpi/wakeup
        echo "Отключено пробуждение для: $dev"
    fi
done

echo "--- 5. Пересборка Initramfs (mkinitcpio) ---"
if command -v mkinitcpio >/dev/null 2>&1; then
    echo "Запуск mkinitcpio -P..."
    mkinitcpio -P
else
    echo "ВНИМАНИЕ: mkinitcpio не найден. Если у тебя другой способ сборки образа (например, dracut), запусти его вручную."
fi

echo "--------------------------------------------------------"
echo "ГОТОВО! Настройки применены."
echo "ВАЖНО: Теперь тебе нужно ПЕРЕЗАГРУЗИТЬ компьютер."
echo "После перезагрузки попробуй отправить его в сон."
echo "--------------------------------------------------------"
