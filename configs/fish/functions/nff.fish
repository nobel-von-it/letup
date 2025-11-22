function nff
    set file_path (fzf --preview "bat --color=always {}")
    if test -z "$file_path"
        return 1
    end
    set abs_file_path (realpath "$file_path")
    set project_root "$abs_file_path"
    while test "$project_root" != "/"
        set project_root (dirname "$project_root")
        if test -d "$project_root/.git" \
            or test -f "$project_root/Cargo.toml" \
            or test -d "$project_root/.venv" \
            or test -d "$project_root/node_modules" \
            or test -f "$project_root/package.json" \
            or test -f "$project_root/Makefile" \
            or test -f "$project_root/CMakeLists.txt" \
            or test -f "$project_root/setup.py" \
            or test -f "$project_root/.project" \
            or test -f "$project_root/pom.xml" \
            or test -f "$project_root/build.gradle" \
            or test -f "$project_root/go.mod"
            break
        end
    end
    if test "$project_root" = "/"
        set project_root (dirname "$abs_file_path")
    end
    set rel_file_path (string replace -r "^$project_root/" "" "$abs_file_path")
    cd "$project_root"
    nvim "$rel_file_path"
end
