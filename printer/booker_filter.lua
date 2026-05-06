local is_frontmatter = true
local skipping_section = false
local image_count = 0

function Blocks(blocks)
    local new_blocks = {}
    local skip_next = false

    for i, block in ipairs(blocks) do
        if skip_next then
            skip_next = false
            goto continue
        end

        if block.t == "Para" or block.t == "Plain" then
            local has_img = false
            pandoc.walk_block(block, {
                Image = function(el)
                    image_count = image_count + 1
                    if image_count <= 2 then has_img = true end
                end
            })
            if has_img then goto continue end
        end

        if block.t == "Header" then
            local text = pandoc.utils.stringify(block)
            local ltext = pandoc.text.lower(text)

            local is_real_start = ltext:find("введение") or 
                                 ltext:find("предисловие") or 
                                 ltext:match("^часть") or 
                                 ltext:match("^глава") or
                                 text:match("^%d+$")

            if is_real_start then
                is_frontmatter = false
                skipping_section = false
            end

            if ltext:find("содержание") or 
               ltext:find("оглавление") or 
               ltext:find("информация") or 
               ltext:find("серия «") or
               ltext:find("about the author") then
                skipping_section = true
                goto continue
            end

            if i < #blocks and blocks[i+1].t == "Header" then
                local next_text = pandoc.utils.stringify(blocks[i+1])
                if text:match("^%d+$") or ltext:match("^глава %d+$") or ltext:match("^часть %d+$") then
                    local combined = text .. ". " .. next_text
                    table.insert(new_blocks, pandoc.Header(block.level, pandoc.Str(combined)))
                    skip_next = true
                    is_frontmatter = false
                    skipping_section = false
                    goto continue
                end
            end

            if is_frontmatter then goto continue end
        end

        if skipping_section then
            goto continue
        end

        table.insert(new_blocks, block)
        ::continue::
    end
    return new_blocks
end

function Link(el)
    if not el.target:match("^http") then
        return el.content
    end
end
