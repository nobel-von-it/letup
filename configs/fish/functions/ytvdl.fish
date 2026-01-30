function ytvdl
    yt-dlp -f "bestvideo[height<=720]+bestaudio" \
        --postprocessor-args "ffmpeg:-c:v h264_nvenc -pix_fmt yuv420p -profile:v high -rc vbr -cq 32 -preset fast -movflags +faststart -c:a aac -b:a 96k -ac 2" \
        --merge-output-format mp4 \
        --cookies-from-browser firefox \
        $argv
end
