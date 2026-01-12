function mocount
    fd --full-path "$MO_BASE_PATH" | wc -l | string trim
end
