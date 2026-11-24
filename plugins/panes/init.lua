-- panes: pick a Rex pane by its number, like tmux display-panes.
-- Press the key and every pane of the active tab shows a big number. A digit focuses that pane.
-- Esc, q or any other key keeps the focus where it was. A click outside the floats closes them.
-- The focused pane is green and the others are blue.
--
-- One small float per pane. The float of the focused pane reads the key (bin/panes pick).
-- The others only draw their number and end when the reader ends (bin/panes show).
-- Only the first 9 panes get a number, in reading order: top to bottom, then left to right.
--
-- tyrannosaur.lua calls this file with the table of the "panes" key:
--
--   panes = {
--       keys = { "ctrl+p>q", "alt+q" },   -- optional: key or list of keys for the panes_select action
--       -- Without keys, the action still exists. Bind it yourself: rex.bind("ctrl+p>q", "panes_select").
--       script = "/path/to/bin/panes",    -- optional: default is bin/panes next to this file
--       focused = "9ece6a",               -- optional: RGB hex of the number of the focused pane
--       other = "7aa2f7",                 -- optional: RGB hex of the other numbers
--       width = 0.4, height = 0.5,        -- optional: size of a float as a fraction of its pane
--       theme = { foreground = "#c0caf5", background = "#1a1b26" }, -- optional: theme of the floats
--   }

local LABEL = "panes"
local MAX = 9
local TERMINAL = "com.superlogical.terminal"

-- TokyoNight.
local DEFAULT_THEME = { foreground = "#c0caf5", background = "#1a1b26", scheme = "dark" }

local here = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("[^/]*$", "")

-- Leaves of a layout tree: nested tables, and a pane node has block_id and rect.
local function collect(node, out)
    if type(node) ~= "table" then return end
    if node.block_id and node.rect then
        out[#out + 1] = { block_id = node.block_id, rect = node.rect }
        return
    end
    for _, child in pairs(node) do collect(child, out) end
end

-- Panes of the active tab in reading order.
local function panes_of(session_id)
    local view, err = rex.session.view { session_id = session_id }
    if view == nil then error(err or "session.view returned no result", 0) end
    local panes = {}
    for _, window in ipairs(view.windows) do
        if window.window_id == view.active_window_id then
            for _, layer in ipairs(window.layers) do
                if layer.kind == "tiled" then collect(layer.layout, panes) end
            end
        end
    end
    table.sort(panes, function(a, b)
        if a.rect[2] ~= b.rect[2] then return a.rect[2] < b.rect[2] end
        return a.rect[1] < b.rect[1]
    end)
    while #panes > MAX do panes[#panes] = nil end
    return panes
end

return function(opts, lib)
    local keys = lib.keys(opts.keys, "panes.keys")
    local script = opts.script or (here .. "bin/panes")
    local focused = opts.focused or "9ece6a"
    local other = opts.other or "7aa2f7"
    local width, height = opts.width or 0.4, opts.height or 0.5
    local theme = opts.theme or DEFAULT_THEME

    local function float(pane, argv, focus)
        local r = pane.rect
        local w, h = r[3] * width, r[4] * height
        local made, err = rex.session.new_layer {
            bounds = { r[1] + (r[3] - w) / 2, r[2] + (r[4] - h) / 2, w, h },
            focus = focus,
            layout = rex.layout.block {
                flavor = TERMINAL .. ".shell",
                label = LABEL,
                options = { command = argv, exit = { on_completion = true }, theme = theme },
            },
        }
        if made == nil then error(err or "new_layer returned no result", 0) end
        return made.block_ids[1]
    end

    rex.action {
        name = "panes_select",
        title = "Panes: Select by Number",
        description = "Show a number over each pane. Press it to focus that pane.",
        run = function(ctx)
            if not ctx.block_id then error("panes_select: no focused pane", 0) end

            -- The picker is already open: any key but a digit closes it, so Esc closes it.
            if lib.close_if_open(ctx, LABEL) then return end

            local panes = panes_of(ctx.session_id)
            if #panes < 2 then return end

            local blocks, reader = {}, 1
            for i, p in ipairs(panes) do
                blocks[i] = p.block_id
                if p.block_id == ctx.block_id then reader = i end
            end

            local pick = { script, "pick", tostring(reader), focused, ctx.session_id, ctx.block_id }
            for _, id in ipairs(blocks) do pick[#pick + 1] = id end
            local reader_block = float(panes[reader], pick, true)

            for i, p in ipairs(panes) do
                if i ~= reader then
                    float(p, { script, "show", tostring(i), other, ctx.session_id, reader_block }, false)
                end
            end
        end,
    }
    lib.bind(keys, "panes_select")
end
