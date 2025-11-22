function ytpldl_wsl --wraps="yt-dlp -f 'ba' --yes-playlist --extract-audio --audio-format mp3 --audio-quality 0 --cookies '/mnt/c/Users/nerd/AppData/Roaming/Mozilla/Firefox/Profiles/xigln4bf.default-release/cookies.sqlite'" --description "alias ytpldl_wsl yt-dlp -f 'ba' --yes-playlist --extract-audio --audio-format mp3 --audio-quality 0 --cookies '/mnt/c/Users/nerd/AppData/Roaming/Mozilla/Firefox/Profiles/xigln4bf.default-release/cookies.sqlite'"
  yt-dlp -f 'ba' --yes-playlist --extract-audio --audio-format mp3 --audio-quality 0 --cookies '/mnt/c/Users/nerd/AppData/Roaming/Mozilla/Firefox/Profiles/xigln4bf.default-release/cookies.sqlite' $argv
        
end
