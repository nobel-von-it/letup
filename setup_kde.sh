#!/usr/bin/env bash
set -e

echo "=== 1. Настройка PiP видео поверх всех окон ==="
RULE_ID="pip_always_on_top"
kwriteconfig6 --file kwinrulesrc --group "$RULE_ID" --key Description "Browser PiP Always on Top"
kwriteconfig6 --file kwinrulesrc --group "$RULE_ID" --key wmclass "firefox"
kwriteconfig6 --file kwinrulesrc --group "$RULE_ID" --key wmclassmatch 1
kwriteconfig6 --file kwinrulesrc --group "$RULE_ID" --key types 1
kwriteconfig6 --file kwinrulesrc --group "$RULE_ID" --key title ".*(Picture-in-Picture|Picture in picture|Картинка в картинке).*"
kwriteconfig6 --file kwinrulesrc --group "$RULE_ID" --key titlematch 3
kwriteconfig6 --file kwinrulesrc --group "$RULE_ID" --key above true
kwriteconfig6 --file kwinrulesrc --group "$RULE_ID" --key aboverule 2

# Добавляем правило в общий список правил, если его там ещё нет
EXISTING_RULES=$(kreadconfig6 --file kwinrulesrc --group General --key rules 2>/dev/null || echo "")
if [[ ",$EXISTING_RULES," != *",$RULE_ID,"* ]]; then
    NEW_RULES="${EXISTING_RULES:+$EXISTING_RULES,}$RULE_ID"
    kwriteconfig6 --file kwinrulesrc --group General --key rules "$NEW_RULES"
fi

echo "=== 2. Настройка виртуальных рабочих столов ==="
# Устанавливаем минимум 3 рабочих стола для работы жестов
kwriteconfig6 --file kwinrc --group Desktops --key Number 3
kwriteconfig6 --file kwinrc --group Desktops --key Rows 1

echo "=== 3. Отключение анимации скольжения (мгновенное переключение столов) ==="
# Отключаем slide-эффект, чтобы клавиша Meta не съедалась анимацией
kwriteconfig6 --file kwinrc --group Plugins --key slideEnabled false

echo "=== 4. Сброс оконного действия колёсика (чтобы окна не уезжали) ==="
kwriteconfig6 --file kwinrc --group MouseBindings --key CommandAllWheel "Nothing"

echo "=== 5. Настройка клавиши Meta на Обзор (Overview) ==="
# Назначаем одиночную Meta на Обзор
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key Overview "Meta,Meta+W,Toggle Overview"

# Отключаем скрытый шорткат меню приложений, чтобы убрать конфликт
kwriteconfig6 --file kglobalshortcutsrc --group plasmashell --key "activate application launcher" "none,none,Activate Application Launcher"

echo "=== 6. Настройка поиска в Обзоре для запуска приложений ==="
# Отключаем затемнение/фильтрацию открытых окон в Обзоре
kwriteconfig6 --file kwinrc --group Effect-overview --key FilterWindows false

# Отключаем поиск среди открытых окон в KRunner, чтобы искались программы
kwriteconfig6 --file krunnerrc --group Plugins --key windowsEnabled false

echo "=== 7. Настройка keyd для Meta + Scroll (переключение столов мышью) ==="
if command -v keyd >/dev/null 2>&1; then
    sudo mkdir -p /etc/keyd
    sudo tee /etc/keyd/default.conf > /dev/null << 'EOF'
[ids]
*
2b89:0043
0911:5288

[meta]
scrollup = C-M-left
scrolldown = C-M-right
EOF
    sudo systemctl enable --now keyd
    sudo keyd reload || true
    echo "keyd успешно настроен и перезапущен."
else
    echo "Предупреждение: keyd не установлен. Установите его: sudo pacman -S keyd"
fi

echo "=== 8. Применение настроек KWin и системы ==="
qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null || true

echo "Готово! Все настройки GNOME-поведения в KDE успешно применены."
