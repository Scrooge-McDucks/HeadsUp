# Heads Up tests

A test suite that runs the addon's real Lua against a stubbed World of Warcraft
client, so logic can be checked without launching the game.

These files are **development only**. `.pkgmeta` lists `tests` under `ignore`,
so the packager leaves them out of the released addon zip.

## Running

Needs [lupa](https://pypi.org/project/lupa/) (a Lua runtime embedded in Python):

```sh
python3 -m venv .venv
.venv/bin/pip install lupa
.venv/bin/python tests/run_tests.py
```

Run a subset by passing name fragments:

```sh
.venv/bin/python tests/run_tests.py core watcher
```

Exit status is 0 when every assertion passes, 1 otherwise, so it drops straight
into CI.

## Layout

| File | Covers |
|---|---|
| `wow_stub.lua` | The fake game client, plus the `H` handle tests drive it with |
| `run_tests.py` | Discovers `test_*.lua`, runs each in a fresh Lua state |
| `test_core.lua` | Saved-variable defaults, secret-value helper, slash commands, login warning |
| `test_speech.lua` | Wording, countdown numbers, voice fallback, speech errors |
| `test_watcher.lua` | Which bars become callouts, countdown timing, pause/stop/clear, repeat suppression, `/hu test` |
| `test_options.lua` | Options window preview, spell box, voice menu |
| `test_integration.lua` | TOC matches the files on disk, everything compiles, icon exists, end-to-end callouts |

## How the stub works

`wow_stub.lua` installs stand-ins for every global the addon touches (`CreateFrame`,
`C_VoiceChat`, `C_AddOns`, `C_Spell`, `BigWigsLoader`, `GetTime`, `Settings`, ...)
and returns a handle, `H`, with assertions and a `newEnv` that loads the addon:

```lua
local H   = dofile(TESTS_DIR .. "/wow_stub.lua")
local ctx = H.newEnv({ db = { lead = 5 }, tank = true })

H.try("name", function()
    ctx.emit("BigWigs_StartBar", H.module({ [1] = "TANK" }, { [1] = "Blade Combo" }),
        1, "Blade Combo", 12, nil, false, 12, nil, nil)
    ctx.advance(12)                       -- step the fake clock and countdown
    H.eq("first callout", ctx.spoken[1].msg, "Blade Combo, tank buster in 5")
end)
H.report()                                -- totals, and sets TEST_FAILURES
```

`ctx.advance` moves the fake clock and runs the countdown ticker in 0.1s steps.
`ctx.fire` sends game events, `ctx.emit` sends BigWigs messages, and
`ctx.spoken` records every line the addon would speak.

Nothing reaches the network or a real client. A "tick" is a direct call to the
ticker's `OnUpdate` handler.

### Known limits

- The host Lua is newer than WoW's 5.1, so 5.1-specific syntax is not validated
  here. Run `lua5.1` locally if you want to check that.
- BigWigs and LittleWigs are stubbed. The tests check Heads Up's side of the
  messages, not that BigWigs really sends them in that form.
- Text-to-speech `overlap` behaviour, the dropdown templates, and what the real
  client does with a missing voice can only be confirmed in game.
