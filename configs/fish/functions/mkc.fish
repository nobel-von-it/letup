function mkc
    if test (count $argv) -lt 1
        echo "Usage: mkc <dir>"
        return 1
    end
    mkdir -p $argv[1]
    cd $argv[1]
end
