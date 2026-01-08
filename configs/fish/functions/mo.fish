function mo
    if not set -q MO_BASE_PATH
        echo "Ошибка: Переменная MO_BASE_PATH не установлена."
        return 1
    end

    set -l selected_file (fd . "$MO_BASE_PATH" --type f -e md -e txt | fzf \
        --preview 'bat --color=always --style=numbers {}' \
        --height 80% --layout=reverse --border --prompt="Magnum Opus > ")

    if test -z "$selected_file"
        return
    end

    set -l target_dir (dirname "$selected_file")
    set -l file_name (basename "$selected_file")

    set -l old_pwd (pwd)
    
    cd "$target_dir"
    env NVIM_APPNAME=litex nvim "$file_name"
    
    cd "$old_pwd"
end
