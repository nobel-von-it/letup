function cpi
    if test (count $argv) -lt 2
        echo "Usage: cp <from> <to>"
        return 1
    end
    install -D $argv[1] $argv[2]
end
