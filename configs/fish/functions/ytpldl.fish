function ytpldl --wraps='yt-dlp' --description 'Download YouTube playlist/channel as MP3s in best quality with metadata and square covers'
    set -l ff_path firefox
    if test -d ~/.config/mozilla/firefox
        set ff_path firefox:~/.config/mozilla/firefox
    end

    yt-dlp \
        -f 'ba' \
        --extract-audio \
        --audio-format mp3 \
        --audio-quality 0 \
        --yes-playlist \
        --embed-metadata \
        --embed-thumbnail \
        --ppa 'EmbedThumbnail+ffmpeg_o:-c:v mjpeg -vf crop=ih:ih' \
        --replace-in-metadata 'artist,uploader,playlist_title,album,meta_album' '(?i)\s*-\s*Topic$' '' \
        --replace-in-metadata 'playlist_title' '(?i)Uploads from\s+' '' \
        --replace-in-metadata 'title' '(?i)\s*[\(\[](official\s+)?(video|audio|music\s+video|lyric\s+video|lyric|visualizer|hd|remastered)(?:\s+(?:video|audio|remastered|version))?[\)\]]' '' \
        --replace-in-metadata 'title' '(?i)\s*\|\s*(official\s+)?(video|audio|music\s+video|lyric\s+video|lyric|visualizer|hd)' '' \
        --parse-metadata 'title:(?P<artist>.+?)\s*[-–—]\s*(?P<title>.+)' \
        --parse-metadata '%(artist,uploader)s:%(meta_artist)s' \
        --parse-metadata '%(title)s:%(meta_title)s' \
        --parse-metadata '%(playlist_title|YouTube)s:%(meta_album)s' \
        --cookies-from-browser $ff_path \
        -o '%(artist,uploader)s - %(title)s.%(ext)s' \
        $argv
end
