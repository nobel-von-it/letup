#!/bin/bash
# Комплексный скрипт исправления проблем со сном (AMD + NVIDIA + Realtek 8822ce)
# Совместимо с Gigabyte B550 Gaming X V2 (Rev 1.3/1.4)
# Сценарий должен быть запущен с правами sudo.

set -e

if [[ $EUID -ne 0 ]]; then
   echo "Ошибка: Этот скрипт должен быть запущен через sudo."
   exit 1
fi

CHANGED=0
IS_ARCH=false
if [ -f /etc/arch-release ]; then
    IS_ARCH=true
fi


# Хелпер для атомарного обновления файлов только при изменении
update_file_if_changed() {
    local file="$1"
    local description="$2"
    local tmp_file
    tmp_file=$(mktemp)
    
    cat > "$tmp_file"
    
    if [ -f "$file" ] && cmp -s "$file" "$tmp_file"; then
        echo "Конфигурация $description уже актуальна в $file."
        rm "$tmp_file"
    else
        mkdir -p "$(dirname "$file")"
        mv "$tmp_file" "$file"
        chmod 644 "$file"
        echo "Конфигурация $description обновлена в $file."
        CHANGED=1
    fi
}


echo "--- 0. Проверка и установка зависимостей ---"
if [ "$IS_ARCH" = true ]; then
    DEPENDENCIES=("kmod" "grep" "sed")
else
    DEPENDENCIES=("kernelstub" "kmod" "grep" "sed")
fi

MISSING_DEPS=()
for dep in "${DEPENDENCIES[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        MISSING_DEPS+=("$dep")
    fi
done

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo "Установка недостающих зависимостей: ${MISSING_DEPS[*]}..."
    if [ "$IS_ARCH" = true ]; then
        pacman -Sy --noconfirm "${MISSING_DEPS[@]}"
    else
        apt update
        apt install -y "${MISSING_DEPS[@]}"
    fi
else
    echo "Все зависимости на месте."
fi


if [ "$IS_ARCH" = true ]; then
    MK_CONF="/etc/mkinitcpio.conf"
    if [ -f "$MK_CONF" ]; then
        # Читаем текущие модули, убирая скобки
        current_line=$(grep "^MODULES=" "$MK_CONF")
        # Извлекаем содержимое между скобками
        current_modules=$(echo "$current_line" | sed 's/MODULES=(\(.*\))/\1/')
        new_modules="$current_modules"
        
        MODS_ADDED=0
        for mod in "${NVIDIA_MODULES[@]}"; do
            # Проверяем наличие модуля как отдельного слова
            if [[ ! " $current_modules " =~ " $mod " ]]; then
                new_modules="$new_modules $mod"
                echo "Добавлен модуль $mod в mkinitcpio.conf."
                MODS_ADDED=1
                CHANGED=1
            fi
        done
        
        if [ $MODS_ADDED -eq 1 ]; then
            # Очищаем лишние пробелы и обновляем строку
            new_modules=$(echo "$new_modules" | xargs)
            sed -i "s|^MODULES=.*|MODULES=($new_modules)|" "$MK_CONF"
        else
            echo "Все модули NVIDIA уже присутствуют в $MK_CONF."
        fi
    fi
else
    MODULES_FILE="/etc/initramfs-tools/modules"
    for mod in "${NVIDIA_MODULES[@]}"; do
        if ! grep -q "^$mod" "$MODULES_FILE"; then
            echo "$mod" >> "$MODULES_FILE"
            echo "Добавлен модуль $mod в $MODULES_FILE."
            CHANGED=1
        else
            echo "Модуль $mod уже присутствует в $MODULES_FILE."
        fi
    done
fi



echo "--- 2. Настройка параметров модуля NVIDIA ---"
update_file_if_changed /etc/modprobe.d/nvidia.conf "параметров NVIDIA" <<EOF
# Фикс для сохранения видеопамяти при уходе в сон (нужно для Wayland/COSMIC)
options nvidia NVreg_PreserveVideoMemoryAllocations=1
# Включение Dynamic Power Management для снижения потребления в простое
options nvidia NVreg_DynamicPowerManagement=0x02
options nvidia NVreg_TemporaryFilePath=/var/tmp
# Включение modesetting
options nvidia_drm modeset=1
EOF


echo "--- 3. Отключение источников мгновенного пробуждения (ACPI) ---"
DEVS=("GP12" "GP13" "XHC0" "GPP0" "GPP8" "PTXH" "PT28" "PT29")

# Удаляем старый некорректный метод
if [ -f /etc/tmpfiles.d/disable-wakeup.conf ]; then
    rm /etc/tmpfiles.d/disable-wakeup.conf
    echo "Удален старый конфиг tmpfiles.d."
fi

echo "Создание systemd-сервиса для управления пробуждением..."
SERVICE_FILE="/etc/systemd/system/disable-acpi-wakeup.service"
SERVICE_CHANGED=0

# Сохраняем текущее состояние CHANGED
OLD_CHANGED=$CHANGED
CHANGED=0

update_file_if_changed "$SERVICE_FILE" "ACPI Wakeup Service" <<EOF
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

if [ $CHANGED -eq 1 ]; then
    SERVICE_CHANGED=1
fi
# Возвращаем глобальный CHANGED и учитываем изменения
CHANGED=$((OLD_CHANGED | CHANGED))

if [ $SERVICE_CHANGED -eq 1 ] || ! systemctl is-enabled --quiet disable-acpi-wakeup.service; then
    systemctl daemon-reload
    systemctl enable disable-acpi-wakeup.service
    systemctl restart disable-acpi-wakeup.service
    echo "Сервис disable-acpi-wakeup обновлен и перезапущен."
else
    echo "Сервис disable-acpi-wakeup уже настроен и активен."
fi



echo "--- 4. Включение сервисов NVIDIA для сна ---"
NVIDIA_SERVICES=("nvidia-suspend.service" "nvidia-hibernate.service" "nvidia-resume.service")
for svc in "${NVIDIA_SERVICES[@]}"; do
    if ! systemctl is-enabled --quiet "$svc"; then
        systemctl enable "$svc"
        echo "Сервис $svc активирован."
        # Активация сервисов обычно не требует пересборки initramfs, но мы можем пометить изменение
        # CHANGED=1
    else
        echo "Сервис $svc уже активирован."
    fi
done


echo "--- 5. Отключение заморозки сессий systemd ---"
update_file_if_changed /etc/systemd/system/systemd-suspend.service.d/override.conf "systemd-suspend override" <<EOF
[Service]
Environment=SYSTEMD_SLEEP_FREEZE_USER_SESSIONS=false
EOF


echo "--- 6. Обновление параметров ядра ---"
PARAMS=("nvidia_drm.modeset=1" "nvidia_drm.fbdev=1" "nvidia.NVreg_PreserveVideoMemoryAllocations=1")


if command -v kernelstub >/dev/null 2>&1; then
    for param in "${PARAMS[@]}"; do
        if ! kernelstub -p | grep -q "$param"; then
            echo "Добавление $param через kernelstub..."
            kernelstub -a "$param"
            CHANGED=1
        else
            echo "Параметр $param уже присутствует в kernelstub."
        fi
    done
elif [ "$IS_ARCH" = true ]; then
    # Поиск записей systemd-boot
    if [ -d /boot/loader/entries ]; then
        for entry in /boot/loader/entries/*.conf; do
            [ -e "$entry" ] || continue
            for param in "${PARAMS[@]}"; do
                # Создаем паттерн, где - и _ взаимозаменяемы
                pattern=$(echo "$param" | sed 's/[-_]/[-_]/g')
                if ! grep -qE "$pattern" "$entry"; then
                    sed -i "s/^options \(.*\)/options \1 $param/" "$entry"
                    echo "Добавлен параметр $param в $entry"
                    CHANGED=1
                fi
            done
            # Очистка дубликатов (удаляем версию с тире, если есть версия с подчеркиванием)
            if grep -q "nvidia_drm.modeset=1" "$entry" && grep -q "nvidia-drm.modeset=1" "$entry"; then
                sed -i 's/ nvidia-drm.modeset=1//g' "$entry"
                echo "Удален дублирующий параметр nvidia-drm.modeset=1 из $entry"
                CHANGED=1
            fi
        done
    fi
    # Обработка GRUB
    if [ -f /etc/default/grub ]; then
        GRUB_CHANGED=0
        for param in "${PARAMS[@]}"; do
            pattern=$(echo "$param" | sed 's/[-_]/[-_]/g')
            if ! grep -qE "$pattern" /etc/default/grub; then
                sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$param /" /etc/default/grub
                echo "Добавлен параметр $param в GRUB."
                GRUB_CHANGED=1
                CHANGED=1
            fi
        done
        # Очистка дубликатов в GRUB
        if grep -q "nvidia_drm.modeset=1" /etc/default/grub && grep -q "nvidia-drm.modeset=1" /etc/default/grub; then
            sed -i 's/ nvidia-drm.modeset=1//g' /etc/default/grub
            echo "Удален дублирующий параметр nvidia-drm.modeset=1 из GRUB."
            GRUB_CHANGED=1
            CHANGED=1
        fi

        if [ $GRUB_CHANGED -eq 1 ]; then
            NEED_GRUB_MKCONFIG=1
        fi
    fi
else
    echo "ВНИМАНИЕ: Инструмент для настройки параметров ядра не определен."
fi



echo "--- 7. Пересборка Initramfs ---"
if [ $CHANGED -eq 1 ]; then
    if [ "$NEED_GRUB_MKCONFIG" = 1 ]; then
        if command -v grub-mkconfig >/dev/null 2>&1; then
            echo "Обновление конфигурации GRUB..."
            grub-mkconfig -o /boot/grub/grub.cfg
        fi
    fi

    if command -v update-initramfs >/dev/null 2>&1; then
        echo "Обновление initramfs..."
        update-initramfs -u
    elif command -v mkinitcpio >/dev/null 2>&1; then
        echo "Пересборка mkinitcpio..."
        mkinitcpio -P
    else
        echo "ВНИМАНИЕ: Инструмент для пересборки initramfs не найден."
    fi
else
    echo "Изменений не обнаружено. Пересборка initramfs пропущена."
fi



echo "--------------------------------------------------------"
echo "ГОТОВО! Все системные настройки применены автоматически."
echo "Проверьте файлы в /boot/loader/entries/ на наличие новых параметров."
echo "ТЕПЕРЬ ПЕРЕЗАГРУЗИТЕСЬ."
echo "--------------------------------------------------------"
