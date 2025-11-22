function ytpldl --wraps="yt-dlp -f 'ba' --yes-playlist --extract-audio --audio-format mp3 --audio-quality 0 --cookies-from-browser firefox" --description "alias ytpldl yt-dlp -f 'ba' --yes-playlist --extract-audio --audio-format mp3 --audio-quality 0 --cookies-from-browser firefox"
  yt-dlp -f 'ba' --yes-playlist --extract-audio --audio-format mp3 --audio-quality 0 --cookies-from-browser firefox $argv
        
end
