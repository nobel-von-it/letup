function ytpldl
    set -l ff_path firefox
    if test -d ~/.config/mozilla/firefox
        set ff_path firefox:~/.config/mozilla/firefox
    end
    yt-dlp -f 'ba' --yes-playlist --extract-audio --audio-format mp3 --audio-quality 0 --cookies-from-browser $ff_path $argv
end
