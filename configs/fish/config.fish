# ~/.config/fish/config.fish

# =============================================================================
# 1. ИНТЕРФЕЙС И ЦВЕТА
# =============================================================================
if status is-interactive
    set -g fish_color_normal aab1be
    set -g fish_color_command 7a8ca3
    set -g fish_color_keyword 9e8ba3
    set -g fish_color_quote 8da18d
    set -g fish_color_redirection aab1be
    set -g fish_color_end 889ca6
    set -g fish_color_error b07b7b
    set -g fish_color_param 9cb0ba
    set -g fish_color_comment 4b5263
    set -g fish_color_selection --background=3e4452
    set -g fish_color_search_match --background=3e4452
    set -g fish_color_operator 889ca6
    set -g fish_color_escape 9e8ba3
    set -g fish_color_autosuggestion 4b5263
    set -g fish_pager_color_progress 4b5263
    set -g fish_pager_color_prefix 7a8ca3
    set -g fish_pager_color_completion aab1be
    set -g fish_pager_color_description 4b5263
    set -g fish_pager_color_selected_background --background=3e4452
end

set -U fish_greeting ""
fish_vi_key_bindings


# =============================================================================
# 2. КЛЮЧИ И БЕЗОПАСНОСТЬ (VAULT)
# =============================================================================
function unlock_vault
    # Ensure local GPG agent is updated with current session environment
    gpg-connect-agent "setenv DISPLAY=$DISPLAY" "setenv WAYLAND_DISPLAY=$WAYLAND_DISPLAY" "updatestartuptty" /bye > /dev/null 2>&1

    # SSH Agent Setup
    if not set -q SSH_AUTH_SOCK
        eval (ssh-agent -c) > /dev/null
    end

    # Add local SSH key to agent if present
    if test -f ~/.ssh/id_ed25519
        if not ssh-add -l | grep -q (ssh-keygen -lf ~/.ssh/id_ed25519 | awk '{print $2}')
            ssh-add ~/.ssh/id_ed25519 2>/dev/null
        end
    end

    # Check last backup time to notify user if older than 7 days
    if status is-interactive
        if test -f ~/.vault/.last_backup
            set -l last_backup_time (cat ~/.vault/.last_backup | cut -d'.' -f1)
            set -l current_time (date +%s)
            set -l age (math "$current_time - $last_backup_time")
            set -l week_seconds 604800
            if test "$age" -gt "$week_seconds"
                set -l days (math "floor($age / 86400)")
                echo (set_color yellow) "⚠️  Внимание: Резервная копия хранилища не обновлялась уже $days дн.!" (set_color normal)
                echo (set_color -o cyan) "💡 Запустите 'vault-manager sync' для синхронизации бэкапа." (set_color normal)
            end
        else if test -d ~/.ssh; or test -d ~/.gnupg
            echo (set_color yellow) "⚠️  Внимание: Резервная копия хранилища никогда не создавалась!" (set_color normal)
            echo (set_color -o cyan) "💡 Запустите 'vault-manager sync' для резервного копирования." (set_color normal)
        end
    end
end

if status is-interactive
    unlock_vault
    set -gx GPG_TTY (tty)
end


# =============================================================================
# 3. ОСНОВНЫЕ ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ
# =============================================================================
set -gx EDITOR nvim
# set -gx XDG_DATA_DIRS /var/lib/flatpak/exports/share "$HOME/.local/share/flatpak/exports/share" $XDG_DATA_DIRS
set -gx CASE_SENSITIVE false

# Темизация (синхронизировано с конфигом Niri)
# set -gx QT_QPA_PLATFORMTHEME gtk3
# set -gx GTK_THEME Adwaita:dark

# Импут-методы (IBus как запасной, fcitx5 отключен)
# set -gx GLFW_IM_MODULE ibus


# =============================================================================
# 4. PATH И СИСТЕМНЫЕ ПУТИ
# =============================================================================
set -gx PATH "$HOME/.local/bin" \
             "$HOME/.local/share/bob/nvim-bin" \
             "$HOME/.cargo/bin" \
             "$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/" \
             "$HOME/.ghcup/bin" \
             "/home/nimirus/go/bin" \
             "/opt/cuda/bin" \
             "/usr/lib/emscripten" \
             $PATH

set -gx LD_LIBRARY_PATH /opt/cuda/lib64 $LD_LIBRARY_PATH


# =============================================================================
# 5. РАЗРАБОТКА (DEVELOPMENT)
# =============================================================================
set -gx PROJECTS "$HOME/Dev/projs/"
set -gx TESTS "$HOME/Dev/tests/"
set -gx LOCAL_HOST "127.0.0.1:3000"

# Android & Java
set -gx ANDROID_HOME "$HOME/Android/Sdk"
set -gx JAVA_HOME "/opt/android-studio/jbr"
fish_add_path "$JAVA_HOME/bin"


# =============================================================================
# 6. ЛИЧНЫЕ ИНСТРУМЕНТЫ И ПУТИ
# =============================================================================
set -gx LETUP "$HOME/Downloads/Git/letup"
set -gx VID "$HOME/Videos/OBS/"
set -gx STEAM_GAMES "$HOME/.local/share/Steam/steamapps/compatdata"
set -gx SYNCTHING_ADDR "127.0.0.1:8384"

# MagnumOpus
set -gx MO_BASE_PATH "$HOME/Documents/MagnumOpus"
set -gx MO_SCRIPTS "$LETUP/mo-scripts"
set -gx MO_EDITOR nvim
