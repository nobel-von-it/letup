function ytmudl --wraps="yt-dlp -f 'ba' --extract-audio --no-playlist --audio-format mp3 --audio-quality 0 --cookies-from-browser firefox" --description "alias ytmudl yt-dlp -f 'ba' --extract-audio --no-playlist --audio-format mp3 --audio-quality 0 --cookies-from-browser firefox"
  yt-dlp -f 'ba' --extract-audio --no-playlist --audio-format mp3 --audio-quality 0 --cookies-from-browser firefox $argv
        
end
