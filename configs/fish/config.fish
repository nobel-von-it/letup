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

fish_vi_key_bindings

set -U fish_greeting ""

# Path setup
set -gx PATH /opt/cuda/bin "$HOME/.local/bin" "$HOME/.ghcup/bin" "$HOME/.cargo/bin" "$HOME/.local/share/bob/nvim-bin" "$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/" $PATH
set -gx LD_LIBRARY_PATH /opt/cuda/lib64 $LD_LIBRARY_PATH
set -gx EDITOR nvim
set -gx LOCAL_HOST "127.0.0.1:3000"

# Case sensitivity
set -gx CASE_SENSITIVE false
set -gx QT_QPA_PLATFORMTHEME qt5ct
set -gx GTK_THEME Adwaita-dark

set -gx PROJECTS "$HOME/Dev/projs/"
set -gx TESTS "$HOME/Dev/tests/"

set -gx GTK_IM_MODULE fcitx
set -gx QT_IM_MODULE fcitx
set -gx XMODIFIERS @im=fcitx
set -gx SDL_IM_MODULE fcitx
set -gx GLFW_IM_MODULE ibus

set -gx MO_BASE_PATH "$HOME/Documents/MagnumOpus"
set -gx LETUP "$HOME/Downloads/Git/letup"

# SYM Syncthing
set -gx SYNCTHING_ADDR "127.0.0.1:8384"
