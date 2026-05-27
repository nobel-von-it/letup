function ytlecdl --wraps="yt-dlp" --description "Download YouTube playlist/video as MP3 with perfect tagging and square covers"
    yt-dlp \
        --extract-audio \
        --audio-format mp3 \
        --audio-quality 5 \
        --embed-metadata \
        --embed-thumbnail \
        --ppa "EmbedThumbnail+ffmpeg_o:-c:v mjpeg -vf crop=ih:ih" \
        --parse-metadata 'title:^(?:\d{1,3}(?:\.\d{1,3})?[\s.-]+)*(?P<title>.+)$' \
        --parse-metadata "%(playlist_title|YouTube)s:%(album)s" \
        --parse-metadata "%(playlist_uploader|YouTube)s:%(album_artist)s" \
        --parse-metadata "%(playlist_index|1)s:%(track_number)s" \
        --cookies-from-browser firefox \
        --sleep-interval 5 \
        --max-sleep-interval 15 \
        -o "%(playlist_index&{} - |)s%(title)s.%(ext)s" \
        $argv
end
