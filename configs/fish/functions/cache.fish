function cache
    sudo pacman -Sc
    sudo rm -rf /var/cache/pacman/pkg/download-*
    yay -Sc
end
