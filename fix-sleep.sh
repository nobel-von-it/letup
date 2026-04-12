#!/bin/bash
# Комплексный скрипт исправления проблем со сном (AMD + NVIDIA + Realtek 8822ce)
# Совместимо с Gigabyte B550 Gaming X V2 (Rev 1.3/1.4)
# Сценарий должен быть запущен с правами sudo.

set -e

if [[ $EUID -ne 0 ]]; then
   echo "Ошибка: Этот скрипт должен быть запущен через sudo."
   exit 1
fi

echo "--- 1. Настройка Early KMS в mkinitcpio.conf ---"
if grep -q "MODULES=()" /etc/mkinitcpio.conf; then
    sed -i 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    echo "Записаны модули NVIDIA в MODULES."
else
    if ! grep -q "nvidia" /etc/mkinitcpio.conf; then
        echo "ВНИМАНИЕ: MODULES уже содержит значения, но модули NVIDIA не найдены. Добавьте их вручную в /etc/mkinitcpio.conf."
    else
        echo "Модули NVIDIA уже присутствуют в mkinitcpio.conf."
    fi
fi

echo "--- 2. Настройка параметров модуля NVIDIA ---"
mkdir -p /etc/modprobe.d
cat <<EOF > /etc/modprobe.d/nvidia.conf
# Фикс для сохранения видеопамяти при уходе в сон (нужно для Wayland)
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_TemporaryFilePath=/var/tmp
# Включение modesetting
options nvidia_drm modeset=1
EOF
echo "Файл /etc/modprobe.d/nvidia.conf обновлен."

echo "--- 3. Отключение источников мгновенного пробуждения (ACPI) ---"
DEVS=("XHC0" "PTXH" "GPP0" "GPP8" "GP12" "GP13" "PT28" "PT29")

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


echo "--- 4. Создание хука для выгрузки драйверов Realtek ---"
mkdir -p /usr/lib/systemd/system-sleep
cat <<EOF > /usr/lib/systemd/system-sleep/00-unload-modules.sh
#!/bin/sh
case \$1 in
  pre)
    echo "Выгрузка проблемных модулей перед сном..."
    modprobe -r btusb
    modprobe -r rtw88_8822ce rtw88_pci rtw88_core
    ;;
  post)
    echo "Загрузка модулей после пробуждения..."
    modprobe rtw88_8822ce
    modprobe btusb
    ;;
esac
EOF
chmod +x /usr/lib/systemd/system-sleep/00-unload-modules.sh
echo "Хук создана."

echo "--- 5. Отключение заморозки сессий systemd ---"
mkdir -p /etc/systemd/system/systemd-suspend.service.d
cat <<EOF > /etc/systemd/system/systemd-suspend.service.d/override.conf
[Service]
Environment=SYSTEMD_SLEEP_FREEZE_USER_SESSIONS=false
EOF
echo "Override для systemd-suspend создан."

echo "--- 6. Автоматическое обновление параметров загрузчика (systemd-boot) ---"
BOOT_DIR="/boot/loader/entries"
NEW_PARAMS="nvidia-drm.modeset=1 pcie_aspm=off pci=noaer"

if [ -d "$BOOT_DIR" ]; then
    for entry in "$BOOT_DIR"/*.conf; do
        if [ -f "$entry" ]; then
            echo "Обработка $entry..."
            if ! grep -q "nvidia-drm.modeset=1" "$entry"; then
                sed -i "s/options \(.*\)/options \1 $NEW_PARAMS/" "$entry"
                echo "Добавлены параметры в $entry."
            else
                echo "Параметры уже присутствуют в $entry."
            fi
        fi
    done
else
    echo "ВНИМАНИЕ: Директория $BOOT_DIR не найдена. Если у вас не systemd-boot, добавьте параметры ядра вручную."
fi

echo "--- 7. Пересборка Initramfs ---"
if command -v mkinitcpio >/dev/null 2>&1; then
    mkinitcpio -P
else
    echo "ВНИМАНИЕ: mkinitcpio не найден."
fi

echo "--------------------------------------------------------"
echo "ГОТОВО! Все системные настройки применены автоматически."
echo "Проверьте файлы в /boot/loader/entries/ на наличие новых параметров."
echo "ТЕПЕРЬ ПЕРЕЗАГРУЗИТЕСЬ."
echo "--------------------------------------------------------"
