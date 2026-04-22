#!/bin/bash
# Комплексный скрипт исправления проблем со сном (AMD + NVIDIA + Realtek 8822ce)
# Совместимо с Gigabyte B550 Gaming X V2 (Rev 1.3/1.4)
# Сценарий должен быть запущен с правами sudo.

set -e

if [[ $EUID -ne 0 ]]; then
   echo "Ошибка: Этот скрипт должен быть запущен через sudo."
   exit 1
fi

echo "--- 0. Проверка и установка зависимостей ---"
DEPENDENCIES=("kernelstub" "kmod" "grep" "sed")
MISSING_DEPS=()

for dep in "${DEPENDENCIES[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        MISSING_DEPS+=("$dep")
    fi
done

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo "Установка недостающих зависимостей: ${MISSING_DEPS[*]}..."
    sudo apt update
    sudo apt install -y "${MISSING_DEPS[@]}"
else
    echo "Все зависимости на месте."
fi

echo "--- 1. Настройка Early KMS в /etc/initramfs-tools/modules ---"
MODULES_FILE="/etc/initramfs-tools/modules"
NVIDIA_MODULES=("nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm")

for mod in "${NVIDIA_MODULES[@]}"; do
    if ! grep -q "^$mod" "$MODULES_FILE"; then
        echo "$mod" >> "$MODULES_FILE"
        echo "Добавлен модуль $mod в $MODULES_FILE."
    else
        echo "Модуль $mod уже присутствует в $MODULES_FILE."
    fi
done

echo "--- 2. Настройка параметров модуля NVIDIA ---"
mkdir -p /etc/modprobe.d
cat <<EOF > /etc/modprobe.d/nvidia.conf
# Фикс для сохранения видеопамяти при уходе в сон (нужно для Wayland/COSMIC)
options nvidia NVreg_PreserveVideoMemoryAllocations=1
# Включение Dynamic Power Management для снижения потребления в простое
options nvidia NVreg_DynamicPowerManagement=0x02
options nvidia NVreg_TemporaryFilePath=/var/tmp
# Включение modesetting
options nvidia_drm modeset=1
EOF
echo "Файл /etc/modprobe.d/nvidia.conf обновлен."

echo "--- 3. Отключение источников мгновенного пробуждения (ACPI) ---"
DEVS=("GP12" "GP13" "XHC0" "GPP0" "GPP8" "PTXH" "PT28" "PT29")

# Удаляем старый некорректный метод
if [ -f /etc/tmpfiles.d/disable-wakeup.conf ]; then
    rm /etc/tmpfiles.d/disable-wakeup.conf
    echo "Удален старый конфиг tmpfiles.d."
fi

echo "Создание systemd-сервиса для управления пробуждением..."
SERVICE_FILE="/etc/systemd/system/disable-acpi-wakeup.service"
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Disable ACPI Wakeup Devices
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c "for dev in ${DEVS[*]}; do if grep -q \"\$\$dev.*enabled\" /proc/acpi/wakeup; then echo \$\$dev > /proc/acpi/wakeup; fi; done"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable disable-acpi-wakeup.service
systemctl restart disable-acpi-wakeup.service
echo "Сервис disable-acpi-wakeup активирован и запущен."


echo "--- 4. Включение сервисов NVIDIA для сна ---"
systemctl enable nvidia-suspend.service
systemctl enable nvidia-hibernate.service
systemctl enable nvidia-resume.service
echo "Сервисы NVIDIA активированы."

echo "--- 5. Отключение заморозки сессий systemd ---"
mkdir -p /etc/systemd/system/systemd-suspend.service.d
cat <<EOF > /etc/systemd/system/systemd-suspend.service.d/override.conf
[Service]
Environment=SYSTEMD_SLEEP_FREEZE_USER_SESSIONS=false
EOF
echo "Override для systemd-suspend создан."

echo "--- 6. Обновление параметров ядра через kernelstub ---"
if command -v kernelstub >/dev/null 2>&1; then
    echo "Добавление параметров через kernelstub..."
    kernelstub -a "nvidia-drm.modeset=1"
else
    echo "ВНИМАНИЕ: kernelstub не найден. Попробуйте добавить параметры вручную."
fi

echo "--- 7. Пересборка Initramfs ---"
if command -v update-initramfs >/dev/null 2>&1; then
    echo "Обновление initramfs..."
    update-initramfs -u
elif command -v mkinitcpio >/dev/null 2>&1; then
    mkinitcpio -P
else
    echo "ВНИМАНИЕ: Инструмент для пересборки initramfs не найден."
fi

echo "--------------------------------------------------------"
echo "ГОТОВО! Все системные настройки применены автоматически."
echo "Проверьте файлы в /boot/loader/entries/ на наличие новых параметров."
echo "ТЕПЕРЬ ПЕРЕЗАГРУЗИТЕСЬ."
echo "--------------------------------------------------------"
