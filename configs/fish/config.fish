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
    set -l vault_path "/mnt/vault"

    if test -d "$vault_path/.gnupg"
        # GPG Setup
        set -gx GNUPGHOME "$vault_path/.gnupg"
        gpg-connect-agent "setenv DISPLAY=$DISPLAY" "setenv WAYLAND_DISPLAY=$WAYLAND_DISPLAY" "updatestartuptty" /bye > /dev/null 2>&1
        
        # SSH Setup
        if not set -q SSH_AUTH_SOCK
            eval (ssh-agent -c) > /dev/null
        end
        
        if test -f "$vault_path/.ssh/id_ed25519"
            if not ssh-add -l | grep -q (ssh-keygen -lf "$vault_path/.ssh/id_ed25519" | awk '{print $2}')
                ssh-add "$vault_path/.ssh/id_ed25519" 2>/dev/null
            end
        end

        if status is-interactive
            echo (set_color green)"🔒 Vault mounted: GPG & SSH keys active."(set_color normal)
        end
    else
        if set -q GNUPGHOME; set -e GNUPGHOME; end
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
set -gx XDG_DATA_DIRS /var/lib/flatpak/exports/share "$HOME/.local/share/flatpak/exports/share" $XDG_DATA_DIRS
set -gx CASE_SENSITIVE false

# Темизация (синхронизировано с конфигом Niri)
set -gx QT_QPA_PLATFORMTHEME gtk3
set -gx GTK_THEME Adwaita:dark

# Импут-методы (IBus как запасной, fcitx5 отключен)
set -gx GLFW_IM_MODULE ibus


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
