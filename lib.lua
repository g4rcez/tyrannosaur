-- Helpers that two or more plugins use. tyrannosaur.lua passes this table to each plugin.
local M = {}

M.TERMINAL = "com.superlogical.terminal"

-- A key option is one key or a list of keys. Returns a list. `field` names the option in the error.
function M.keys(value, field)
    if value == nil then return {} end
    if type(value) == "string" then return { value } end
    if type(value) == "table" then
        for _, key in ipairs(value) do
            if type(key) ~= "string" then error(field .. " must be a string or a list of strings", 0) end
        end
        return value
    end
    error(field .. " must be a string or a list of strings", 0)
end

function M.bind(keys, action)
    for _, key in ipairs(keys) do rex.bind(key, action) end
end

-- True when the focused block is a float with this label. A float reads its keys itself, so Esc
-- makes it leave and focus the pane again.
function M.close_if_open(ctx, label)
    local list, err = rex.session.list_blocks {}
    if list == nil then error(err or "list_blocks returned no result", 0) end
    for _, b in ipairs(list.blocks) do
        if b.block_id == ctx.block_id and b.label == label then
            local _, werr = rex.block.call(M.TERMINAL, "write", { block_id = ctx.block_id, data = "\27" })
            if werr ~= nil then error(werr, 0) end
            return true
        end
    end
    return false
end

return M
