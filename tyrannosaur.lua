-- tyrannosaur: every Rex plugin of this repository behind one call.
-- The config has one table per plugin. A plugin that is not in the table is disabled.
-- A plugin is the folder plugins/<name>/, and its init.lua returns function(opts, lib).
--
-- Rex runs this file as a plugin of your init.lua. It returns one function. Call it once from init.lua:
--
--   dofile("/path/to/tyrannosaur/tyrannosaur.lua") {
--       panes  = { keys = { "alt+q" } },
--       flash  = { hints = { "cmd+y", "alt+y" }, flash = { "alt+/" } },
--       scroll = { keys = { "ctrl+p>s" } },
--   }
--
-- A plugin value is a table of options, or true for the defaults. false or nil disables the plugin.
-- A name with no folder in plugins/ is an error, so a typo does not pass in silence.

local here = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("[^/]*$", "")
local lib = dofile(here .. "lib.lua")

local function exists(path)
    local file = io.open(path, "r")
    if file == nil then return false end
    file:close()
    return true
end

return function(config)
    assert(type(config) == "table", "tyrannosaur: the config must be a table with one entry per plugin")

    -- Sorted, so the plugins load in the same order on every reload.
    local names = {}
    for name in pairs(config) do names[#names + 1] = name end
    table.sort(names, function(a, b) return tostring(a) < tostring(b) end)

    for _, name in ipairs(names) do
        local opts = config[name]
        if type(name) ~= "string" or not name:find("^[%w_]+$") then
            error("tyrannosaur: invalid plugin name " .. tostring(name), 0)
        end
        local entry = here .. "plugins/" .. name .. "/init.lua"
        if not exists(entry) then error("tyrannosaur: unknown plugin '" .. name .. "'", 0) end
        if opts == true then opts = {} end
        if opts ~= false then
            if type(opts) ~= "table" then
                error("tyrannosaur: the options of '" .. name .. "' must be a table, true or false", 0)
            end
            dofile(entry)(opts, lib)
        end
    end
end
