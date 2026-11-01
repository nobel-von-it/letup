local M = {}


local PICKS = {
    { key = "+", desc = "[C] Commands", path = "" },
    { key = "d", desc = "Downloads",    path = "~/Downloads" },
    { key = "g", desc = "Git",          path = "~/Git" },
    { key = "t", desc = "This",         path = "~/.config/yazi/plugins" },
    { key = "c", desc = "Config",       path = "~/.config" },
}

local function trim_trash(s)
    return (s:match("^[^%w]*(.-)[^%w]*$"))
end

local function add_new_path(key, path)
    for _, item in ipairs(PICKS) do
        if key == item.key then
            return
        end
    end
    table.insert(PICKS, { key = key, desc = trim_trash(path), path = path })
end

local function delete_path(key)
    local pos = 0
    for i, item in ipairs(PICKS) do
        if item.key == key then
            pos = i
        end
    end
    table.remove(PICKS, pos)
end

local function reassign_key(old_key, new_key)
    for _, item in ipairs(PICKS) do
        if old_key == item.key then
            item.key = new_key
        end
    end
end

local OPTS = {
    {
        key = "a",
        desc = "Add new path",
        action = add_new_path
    },
    {
        key = "d",
        desc = "Delete path",
        action = delete_path
    },
    {
        key = "r",
        desc = "Rename path",
        action = reassign_key
    },
}


function M:entry()
    local opts_len = #OPTS
    local picks_len = #PICKS

    local cands = {}

    for _, item in ipairs(PICKS) do
        table.insert(cands, { on = item.key, desc = string.format("%s (%s)", item.desc, item.path) })
    end
    -- for _, item in ipairs(OPTS) do
    --     table.insert(cands, { on = item.key, desc = item.desc })
    -- end

    local idx = ya.which {
        cands = cands,
        silent = false,
    }

    if idx and PICKS[idx] then
        local fkey = PICKS[idx].key
        if fkey == "+" then
            local commands = {}
            for _, item in ipairs(OPTS) do
                table.insert(commands, { on = item.key, desc = item.desc })
            end

            local command_idx = ya.witch {
                cands = commands,
                silent = false
            }
        end
    end
end

return M
