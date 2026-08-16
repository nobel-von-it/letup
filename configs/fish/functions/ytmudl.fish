function ytmudl --wraps='yt-dlp' --description 'Download YouTube video as MP3 in best quality with metadata and square cover'
    set -l ff_path firefox
    if test -d ~/.config/mozilla/firefox
        set ff_path firefox:~/.config/mozilla/firefox
    end

    yt-dlp \
        -f 'ba' \
        --extract-audio \
        --audio-format mp3 \
        --audio-quality 0 \
        --no-playlist \
        --embed-metadata \
        --embed-thumbnail \
        --ppa 'EmbedThumbnail+ffmpeg_o:-c:v mjpeg -vf crop=ih:ih' \
        --replace-in-metadata 'artist,uploader,album,meta_album' '(?i)\s*-\s*Topic$' '' \
        --replace-in-metadata 'title' '(?i)\s*[\(\[](official\s+)?(video|audio|music\s+video|lyric\s+video|lyric|visualizer|hd|remastered)(?:\s+(?:video|audio|remastered|version))?[\)\]]' '' \
        --replace-in-metadata 'title' '(?i)\s*\|\s*(official\s+)?(video|audio|music\s+video|lyric\s+video|lyric|visualizer|hd)' '' \
        --parse-metadata 'title:(?P<artist>.+?)\s*[-–—]\s*(?P<title>.+)' \
        --parse-metadata '%(artist,uploader)s:%(meta_artist)s' \
        --parse-metadata '%(title)s:%(meta_title)s' \
        --cookies-from-browser $ff_path \
        -o '%(artist,uploader)s - %(title)s.%(ext)s' \
        $argv
end
