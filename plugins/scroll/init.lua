-- scroll: scroll mode. Every key in `keys` enters it, K/J scroll a page, Esc leaves (like resize mode).
-- A full-screen program such as claude runs on the alternate screen, which has no scrollback.
-- There the keys go to the program as PageUp/PageDown. Other panes use Rex's own page scroll.
-- Rex defines the actions scroll_up and scroll_down. Bind them yourself outside the mode if you want.
--
-- tyrannosaur.lua calls this file with the table of the "scroll" key:
--
--   scroll = {
--       keys = { "ctrl+p>s", "cmd+s" },   -- optional: key or list of keys that enter the mode
--   }

local PAGE_KEYS = { up = "\27[5~", down = "\27[6~" }

return function(opts, lib)
    local keys = lib.keys(opts.keys, "scroll.keys")

    local function scroll(direction)
        return function(ctx)
            local modes = ctx.block_id and rex.block.call(lib.TERMINAL, "modes", { block_id = ctx.block_id })
            if modes and modes.screen == "alternate" then
                local _, err = rex.block.call(lib.TERMINAL, "write", { block_id = ctx.block_id, data = PAGE_KEYS[direction] })
                if err ~= nil then error(err, 0) end
            else
                rex.client.queue("client.scroll.page_" .. direction)
            end
        end
    end

    rex.action { name = "scroll_up", title = "Scroll Up", run = scroll("up") }
    rex.action { name = "scroll_down", title = "Scroll Down", run = scroll("down") }

    rex.mode("scroll", { exclusive = true })
    for _, key in ipairs(keys) do
        rex.bind(key, "client.mode.enter", { name = "scroll" })
    end
    -- The mode menu has one entry per binding, and a mode binds actions by name only.
    -- One key per action keeps the menu as compact as the apps menu.
    rex.bind("scroll/k", "scroll_up")
    rex.bind("scroll/j", "scroll_down")
end
