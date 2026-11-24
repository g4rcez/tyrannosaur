# AI instructions: install and configure tyrannosaur

This file is for AI agents (Claude Code, Codex and others) that use the Rex skill (`/rex`) and the
`rex` command. Follow the steps in order. When all checks pass, tyrannosaur is loaded by `init.lua`
with the plugins that the user wants.

tyrannosaur is one Rex plugin that holds many: `flash`, `panes` and `scroll`. `init.lua` loads
`tyrannosaur.lua` once, and the config has one table per plugin. A plugin that is not in the table is disabled.

## Rules

- Work only on macOS. The `flash` plugin uses `pbcopy` and `open`.
- Change only what this file says. Do not edit other keys, modes or actions in `init.lua`.
- Do not run the `flash` binary or `plugins/panes/bin/panes` in your own terminal. They read `/dev/tty`.
  Only the Lua plugins start them.
- Do not run `flash_hint`, `flash_search` or `panes_select` in your own pane. The overlay covers the
  pane and waits for a key. Use a scratch session (step 6).
- If a step fails, read [Troubleshooting](#troubleshooting). Do not retry the same command blindly.
- At the end, tell the user what you changed: the install path, the lines you added to `init.lua`,
  and the keys you chose.

## 1. Check the system

```sh
uname -s            # must print Darwin
rex whoami --json   # must connect to a Rex server
command -v jq       # must print a path (panes needs it)
```

If `rex whoami` fails, the Rex server is not running. Ask the user to start Rex.

## 2. Install

From source (use the directory the user wants, for example `~/src`):

```sh
git clone https://github.com/g4rcez/tyrannosaur "$HOME/src/tyrannosaur"
TYRANNOSAUR_LUA="$HOME/src/tyrannosaur/tyrannosaur.lua"
cargo build --release --manifest-path "$HOME/src/tyrannosaur/plugins/flash/Cargo.toml"   # only for flash
test -f "$TYRANNOSAUR_LUA" && test -x "$HOME/src/tyrannosaur/plugins/flash/target/release/flash" && echo "$TYRANNOSAUR_LUA"
```

The command must print the path. Skip the `cargo build` when the user does not want `flash`. With a
Homebrew formula or a release archive, the path is the `tyrannosaur.lua` that they install.

## 3. Find `init.lua`

Rex reads one file, in this order:

1. the file in the variable `REX_CONFIG`, if it is set
2. `$XDG_CONFIG_HOME/rex/init.lua`, or `~/.config/rex/init.lua` when `XDG_CONFIG_HOME` is not set

```sh
INIT="${REX_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/rex/init.lua}"
INIT="$(realpath "$INIT" 2>/dev/null || echo "$INIT")"   # follow a symlink, as with a dotfiles repository
echo "$INIT"
grep -n "tyrannosaur\|rexflash\|rexpanes" "$INIT"
```

Edit the real file that `realpath` prints. If a `dofile(...tyrannosaur.lua)` line exists, do not add a
second one. Change its table instead. If old `rexflash.lua` or `rexpanes.lua` calls exist, replace them
with the table entries of step 4, and change their action names (`rexflash_hint` → `flash_hint`,
`rexflash_flash` → `flash_search`, `pane_select` → `panes_select`) wherever else `init.lua` uses them.

## 4. Choose the plugins and keys

Ask the user which plugins they want. Default keys: `flash.hints = "ctrl+p>y"`, `flash.flash = "ctrl+p>/"`,
`panes.keys = "ctrl+p>q"`, `scroll.keys = "ctrl+p>s"`. A `>` means a key sequence: press `ctrl+p`, release it,
then press the next key. Check that the keys are free:

```sh
rex keymap | grep -E 'ctrl\+p +(y|/|q|s)( |$)'
```

A line for another action means the key is used. Do not replace it. Choose a free key and tell the user.
If `init.lua` already defines a prefix variable (for example `local PREFIX = "ctrl+p>"`), use it
(`hints = PREFIX .. "y"`).

Add this at the top level of `init.lua`, not inside a function. Use the value of `$TYRANNOSAUR_LUA` as a
literal absolute path. Lua does not expand `~` or shell variables. Keep only the plugins the user wants:

```lua
dofile("/Users/me/src/tyrannosaur/tyrannosaur.lua") {
    flash = { hints = "ctrl+p>y", flash = "ctrl+p>/" },
    panes = { keys = "ctrl+p>q" },
    scroll = { keys = "ctrl+p>s" },
}
```

Keep the call in this form: `dofile("PATH")` directly followed by `{ ... }`. Other options are in the
[README](README.md). A name that is not a plugin is an error (`unknown plugin`).

## 5. Validate

Each command must succeed before the next.

```sh
rex config check     # no line that starts with error, exit status 0
rex config reload    # exit status 0. A failed reload keeps the last working keys.
rex actions | grep -E 'flash_|panes_|scroll_'
rex keymap | grep -E 'flash_|panes_|scroll_'
```

`rex actions` must show one line for each action of an enabled plugin (`flash_hint`, `flash_search`,
`panes_select`, `scroll_up`, `scroll_down`), and `rex keymap` must show your keys.

## 6. Smoke test (optional, no effect on the user's panes)

Use a new session so the overlay never covers your own pane.

```sh
created=$(rex new tyrannosaur-check --window check --json -- sh -c 'echo "see https://example.com and src/main.rs:42"; exec sleep 600') || exit
session=$(printf '%s' "$created" | jq -er '.session_id')
block=$(printf '%s' "$created" | jq -er '.initial_windows[0].block_ids[0]')
sleep 1
rex do flash_hint -s "$session" -b "$block"
sleep 2
float=$(rex block ls -s "$session" --json | jq -r '.. | objects | select(.label? == "flash") | .block_id' | head -1)
rex capture -s "$session" -b "$float" --trim     # each label replaces the first letter of its match
```

Then close the overlay and remove the session. Always do this, also when a step fails:

```sh
rex send-key -s "$session" -b "$float" escape
rex session kill "$session"
```

## 7. Report

Tell the user the path of `tyrannosaur.lua`, the lines you added to `init.lua`, the keys, and that they work
after the reload.

## Troubleshooting

| Symptom | Cause | Fix |
| ------- | ----- | --- |
| `rex config check` prints `open ...tyrannosaur.lua: no such file` | The path in `dofile` is wrong | Run step 2 again and copy the path that it prints. |
| `tyrannosaur: unknown plugin 'x'` | A table name is not a folder in `plugins/` | Use `flash`, `panes` or `scroll`. |
| `tyrannosaur: the options of 'x' must be a table, true or false` | The value is a string or a number | Use `x = { ... }`, `x = true` or `x = false`. |
| `flash: no binary` | The Rust binary is not built | Run the `cargo build` of step 2, or set `flash.bin`. |
| `flash.hints must be a string or a list of strings` | A key option has another type | Use `"alt+y"` or `{ "alt+y", "cmd+y" }`. |
| `rex config reload` fails | An error in `init.lua` | Run `rex config check`, fix the first error, reload again. The last working config stays active. |
| A key does nothing | Another binding takes the key | Run `rex keymap` and choose free keys. |
| Overlay shows `flash: config: unknown field ...` | An option name that `flash` does not know | Remove it or correct the name. Options are in the README. |
| No numbers on the panes | The tab has fewer than 2 panes | `panes` needs at least 2 panes. |
| The `panes` floats close at once | `jq` or `rex` is not on the `PATH` of the floats | `brew install jq`. |
| Overlay has the wrong colors | Rex does not give a global theme to a floating terminal | Pass `theme = { foreground = "#...", background = "#..." }` in the options. |

## Remove

1. Delete the `dofile(...tyrannosaur.lua) { ... }` call from `init.lua`, or delete one table entry to disable
   one plugin.
2. Run `rex config reload`.
