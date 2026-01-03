export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(git)

source $ZSH/oh-my-zsh.sh

export EDITOR='nvim'
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
export LOCAL_HOST="127.0.0.1:3000"

function yy() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# system aliases
alias tset="nvim ~/.zshrc"
alias tup="source ~/.zshrc"

alias nvc="nvim ~/.config/nvim/init.lua"

alias xcopy="xclip -selection clipboard"

alias topr="cd ~/Dev/projs/"
alias tote="cd ~/Dev/tests/"

function mkc {
  mkdir -p "$1"
  cd "$1"
}

function get_touch_id {
  xinput --list | rg -i touchpad | awk -F: '{ split($3, res, " "); split(res[3], id, "="); print id[2] }'
}
function touchpad11 {
  xinput set-prop 11 "libinput Natural Scrolling Enabled" 1
  xinput set-prop 11 "libinput Tapping Enabled" 1
}
function touchpad14 {
  xinput set-prop 14 "libinput Natural Scrolling Enabled" 1
  xinput set-prop 14 "libinput Tapping Enabled" 1
}
function mouse_normalize {
  xinput set-prop 11 "libinput Natural Scrolling Enabled" 0
}

alias ytpldl="yt-dlp -f 'ba' --yes-playlist --extract-audio --audio-format mp3 --audio-quality 0 --cookies-from-browser firefox"
alias ytmudl="yt-dlp -f 'ba' --extract-audio --no-playlist --audio-format mp3 --audio-quality 0 --cookies-from-browser firefox"


function default_monitors {
  xrandr --output HDMI-1 --primary --mode 1920x1080 --rate 60 --pos 0x0 --rotate normal --output eDP-1  --mode 1920x1080 --pos 1920x0 &
}
function single_monitor {
  xrandr --output eDP-1 --primary --mode 1920x1080 --pos 0x0 &
}
function rotate_monitors {
  xrandr --output HDMI-1 --primary --mode 1920x1080 --rate 60 --pos 0x0 --rotate left --output eDP-1  --mode 1920x1080 --pos 1920x0 &
}

function bluedown {
  sudo systemctl stop bluetooth
  sudo systemctl disable bluetooth
}

function blueup {
  sudo systemctl start bluetooth
  sudo systemctl enable bluetooth
}

function nff {
    local file_path=$(fzf --preview="bat --color=always {}")
    
    if [[ -z "$file_path" ]]; then
        return 1
    fi
    
    local abs_file_path=$(realpath "$file_path")
    local project_root="$abs_file_path"
    
    while [[ "$project_root" != "/" ]]; do
        project_root=$(dirname "$project_root")
        
        if [[ -d "$project_root/.git" || -f "$project_root/Cargo.toml" || 
              -d "$project_root/.venv" || -d "$project_root/node_modules" ||
              -f "$project_root/package.json" || -f "$project_root/Makefile" || 
              -f "$project_root/CMakeLists.txt" || -f "$project_root/setup.py" || 
              -f "$project_root/.project" || -f "$project_root/pom.xml" ||
              -f "$project_root/build.gradle" || -f "$project_root/go.mod" ]]; then
            break
        fi
    done
    
    if [[ "$project_root" == "/" ]]; then
        project_root=$(dirname "$abs_file_path")
    fi
    
    local rel_file_path="${abs_file_path#$project_root/}"

    builtin cd "$project_root" && nvim "$rel_file_path"
}

alias vg="valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes --verbose --log-file=valgrind.log"

export SYNCTHING_ADDR="127.0.0.1:8384"
