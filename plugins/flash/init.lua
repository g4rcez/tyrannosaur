-- flash: capture the text of the focused pane, show it with labels, then copy, paste or open what you pick.
--   hints  labels URLs, paths, hashes, IPs and more (patterns).
--   flash  labels whatever you type (search).
-- The pane is captured once, with some scrollback, and shown in a floating terminal over it. The
-- Rust binary of this plugin reads the keys itself, so no key mode is needed and Rex shows no
-- key list. The pane is never drawn on. Press the same key again, or Esc, to close it.
--
-- The view starts on the live screen. Rex does not say where you have scrolled the pane, so the
-- overlay cannot start there. Page Up, Page Down, Up, Down, Home and End scroll the captured
-- history, and only the matches on display get labels.
--
-- Rex draws a title bar and a border on every float and has no option to hide them. They shift the
-- content down and cost a row and a column, so the float is never exactly the pane.
--
-- tyrannosaur.lua calls this file with the table of the "flash" key:
--
--   flash = {
--       hints = { "ctrl+p>y" },          -- optional: key or list of keys for the flash_hint action
--       flash = { "ctrl+p>/" },          -- optional: key or list of keys for the flash_search action
--       -- Every other key goes to the binary. src/config.rs lists them and their defaults.
--       -- An unknown key is an error that shows when you use flash.
--       shift_action = ":paste:",        -- ":copy:", ":paste:", ":open:", "" (copy only) or a shell
--       ctrl_action = ":open:",          -- command that reads the match on stdin ($MODIFIER, $HINT)
--       patterns = { "url", "path" },    -- built-in patterns to use (default: all but "digit")
--       extra = { "ticket (?P<match>[A-Z]+-\\d+)" },  -- your own regexes
--       alphabet = "asdfghjkl",          -- label letters, most important first
--       hint_position = "left",          -- "left" or "right" end of a match
--       hint_style = "1;38;5;0;48;5;12", -- SGR codes
--       highlight_style = "1;38;5;12",
--       dim = false,                     -- true dims the text that is not a match
--       scrollback = 2000,               -- rows of history to capture above the screen (0 = none)
--       bin = "/path/to/flash",          -- optional: the binary to run (default: bin/flash, then target/release/flash)
--       theme = { foreground = "#c0caf5", background = "#1a1b26" }, -- optional: theme of the float
--   }

local TERMINAL = "com.superlogical.terminal"
local LABEL = "flash"

local here = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("[^/]*$", "")

-- Options that Lua reads itself. All others go to the binary.
local LUA_OPTIONS = { hints = true, flash = true, bin = true, theme = true }

local function exists(path)
    local file = io.open(path, "r")
    if file == nil then return false end
    file:close()
    return true
end

-- bin/flash is in a release archive. target/release/flash is the result of `cargo build --release` here.
local function default_bin()
    for _, path in ipairs { here .. "bin/flash", here .. "target/release/flash" } do
        if exists(path) then return path end
    end
    error("flash: no binary. Run `cargo build --release` in " .. here .. " or set the bin option", 0)
end

-- Working directory of a terminal block, as a plain path, or nil. The terminal reports it as a
-- percent-encoded file://host/path URL when the shell sends OSC 7.
local function cwd_of(block_id)
    local pwd = rex.block.call(TERMINAL, "pwd", { block_id = block_id })
    if not (pwd and pwd.pwd) then return nil end
    return (pwd.pwd:gsub("^file://[^/]*", ""):gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

-- Finds the rectangle of a block in a layout tree. The tree is nested tables; a block node has block_id and rect.
local function find_rect(node, block_id)
    if type(node) ~= "table" then return nil end
    if node.block_id == block_id and node.rect then return node.rect end
    for _, child in pairs(node) do
        local rect = find_rect(child, block_id)
        if rect then return rect end
    end
    return nil
end

-- Window fractions {x, y, w, h} of a pane, so the float covers exactly that pane.
local function pane_bounds(ctx)
    local view, err = rex.session.view { session_id = ctx.session_id }
    if view == nil then error(err or "session.view returned no result", 0) end
    for _, window in ipairs(view.windows) do
        for _, layer in ipairs(window.layers) do
            local r = find_rect(layer.layout, ctx.block_id)
            if r then
                local b = layer.bounds
                if layer.kind ~= "tiled" and b then
                    r = { b[1] + r[1] * b[3], b[2] + r[2] * b[4], r[3] * b[3], r[4] * b[4] }
                end
                local w = math.min(r[3], 1 - r[1])
                local h = math.min(r[4], 1 - r[2])
                return { r[1], r[2], w, h }
            end
        end
    end
    return { 0, 0, 1, 1 }
end

return function(opts, lib)
    local hint_keys = lib.keys(opts.hints, "flash.hints")
    local flash_keys = lib.keys(opts.flash, "flash.flash")

    -- The options of the binary, encoded once. An empty Lua table would encode as a JSON list.
    local config = {}
    for key, value in pairs(opts) do
        if not LUA_OPTIONS[key] then config[key] = value end
    end
    local json = "{}"
    if next(config) ~= nil then
        local encoded, jerr = rex.json.encode(config)
        if encoded == nil then error("flash: could not encode the options: " .. tostring(jerr), 0) end
        json = encoded
    end

    local function start(mode)
        return function(ctx)
            if not ctx.block_id then error("flash: no focused pane", 0) end
            -- Esc makes the binary leave and refocus the pane.
            if lib.close_if_open(ctx, LABEL) then return end
            local argv = { opts.bin or default_bin(), mode, "--session", ctx.session_id, "--block", ctx.block_id, "--config", json }
            local cwd = cwd_of(ctx.block_id)
            if cwd then
                table.insert(argv, "--cwd")
                table.insert(argv, cwd)
            end
            local _, err = rex.session.new_layer {
                bounds = pane_bounds(ctx),
                focus = true,
                layout = rex.layout.block {
                    flavor = TERMINAL .. ".shell",
                    label = LABEL,
                    options = { command = argv, exit = { on_completion = true }, theme = opts.theme },
                },
            }
            if err ~= nil then error(err, 0) end
        end
    end

    rex.action {
        name = "flash_hint",
        title = "Flash: Hint",
        description = "Label URLs, paths, hashes and IPs in the focused pane, then copy, paste or open one.",
        run = start("hint"),
    }

    rex.action {
        name = "flash_search",
        title = "Flash: Search",
        description = "Type to search the focused pane, then pick a labelled match to copy, paste or open.",
        run = start("flash"),
    }

    lib.bind(hint_keys, "flash_hint")
    lib.bind(flash_keys, "flash_search")
end
