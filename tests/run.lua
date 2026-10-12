-- Heads Up unit tests. Run from the addon folder:
--   lua tests/run.lua
-- Works with any Lua 5.1+ interpreter. Exit status is 0 when everything passes.

local root = arg[1] or "."
local stubs = dofile(root .. "/tests/stubs.lua")

-- Assertions ---------------------------------------------------------------------
local function fail(msg) error(msg, 3) end
local function eq(actual, expected, label)
    if actual ~= expected then
        fail(("%s: expected %s, got %s"):format(label or "value", tostring(expected), tostring(actual)))
    end
end
local function truthy(v, label) if not v then fail(label or "expected true") end end
local function same(a, b, label)
    if #a ~= #b then
        fail(("%s: expected %d items, got %d (%s)"):format(label or "list", #b, #a, table.concat(a, " | ")))
    end
    for i = 1, #b do
        if a[i] ~= b[i] then
            fail(("%s[%d]: expected %q, got %q"):format(label or "list", i, b[i], a[i]))
        end
    end
end
local function near(actual, expected, tol, label)
    if math.abs(actual - expected) > tol then
        fail(("%s: expected %.2f +/- %.2f, got %.2f"):format(label or "time", expected, tol, actual))
    end
end

-- Test registry ------------------------------------------------------------------
local tests = {}
local function test(name, fn) tests[#tests + 1] = { name = name, fn = fn } end

local BLADE, MAUL = 1, 2
local function bladeModule(extra)
    local flags = { [BLADE] = "TANK_HEALER" }
    for k, v in pairs(extra or {}) do flags[k] = v end
    return stubs.module(flags, { [BLADE] = "Blade Combo", [MAUL] = "Savage Maul" })
end
local function startBar(ctx, module, key, text, time, eventId)
    ctx.emit("BigWigs_StartBar", module, key, text or "Blade Combo", time, nil, false, time, nil, eventId)
end

-- Core ---------------------------------------------------------------------------

test("fresh saved variables get the defaults", function()
    local ctx = stubs.load(root, {})
    eq(ctx.db.lead, 5, "lead")
    eq(ctx.db.countFrom, 3, "countFrom")
    eq(ctx.db.onlyAsTank, true, "onlyAsTank")
    eq(ctx.db.extra[1303488], true, "Savage Maul default")
end)

test("existing saved values are kept", function()
    local ctx = stubs.load(root, { db = { lead = 7 } })
    eq(ctx.db.lead, 7, "lead")
    eq(ctx.db.countFrom, 3, "countFrom filled in")
end)

test("a removed default spell stays removed", function()
    local ctx = stubs.load(root, { db = { extra = {} } })
    eq(ctx.db.extra[1303488], nil, "Savage Maul")
end)

test("Readable rejects secret values and nil", function()
    local ctx = stubs.load(root, {})
    eq(ctx.ns.Readable(stubs.secret("x")), nil, "secret")
    eq(ctx.ns.Readable(nil), nil, "nil")
    eq(ctx.ns.Readable("x"), "x", "plain string")
    eq(ctx.ns.Readable(7), 7, "plain number")
end)

test("/hu lead clamps to 2..10 and floors", function()
    local ctx = stubs.load(root, {})
    SlashCmdList.HEADSUP("lead 1");    eq(ctx.db.lead, 2, "low clamp")
    SlashCmdList.HEADSUP("lead 50");   eq(ctx.db.lead, 10, "high clamp")
    SlashCmdList.HEADSUP("lead 7.6");  eq(ctx.db.lead, 7, "floor")
end)

test("/hu count clamps to 0..10, and 0 turns countdown off", function()
    local ctx = stubs.load(root, {})
    SlashCmdList.HEADSUP("count 99");  eq(ctx.db.countFrom, 10, "high clamp")
    SlashCmdList.HEADSUP("count -3");  eq(ctx.db.countFrom, 0, "low clamp")
    truthy(ctx.countPrinted("Countdown off") == 1, "off message")
end)

test("/hu add and remove change the extra list", function()
    local ctx = stubs.load(root, { db = { extra = {} } })
    SlashCmdList.HEADSUP("add 270487")
    eq(ctx.db.extra[270487], true, "added")
    SlashCmdList.HEADSUP("remove 270487")
    eq(ctx.db.extra[270487], nil, "removed")
end)

test("/hu add without a number prints usage and changes nothing", function()
    local ctx = stubs.load(root, { db = { extra = {} } })
    SlashCmdList.HEADSUP("add abc")
    eq(next(ctx.db.extra), nil, "extra list unchanged")
    eq(ctx.countPrinted("Usage: /hu add <spellID>"), 1, "usage line")
end)

test("/hu remove without a number prints usage", function()
    local ctx = stubs.load(root, {})
    SlashCmdList.HEADSUP("remove")
    eq(ctx.countPrinted("Usage: /hu remove <spellID>"), 1, "usage line")
end)

test("/hu toggle flips enabled", function()
    local ctx = stubs.load(root, {})
    SlashCmdList.HEADSUP("toggle"); eq(ctx.db.enabled, false, "off")
    SlashCmdList.HEADSUP("toggle"); eq(ctx.db.enabled, true, "on")
end)

test("login warns when LittleWigs is missing", function()
    local ctx = stubs.load(root, { lwLoaded = false })
    ctx.fire("PLAYER_LOGIN")
    eq(ctx.countPrinted("LittleWigs isn't loaded"), 1, "warning")
end)

test("login is silent when LittleWigs is loaded", function()
    local ctx = stubs.load(root, { lwLoaded = true })
    ctx.fire("PLAYER_LOGIN")
    eq(ctx.countPrinted("LittleWigs"), 0, "no warning")
end)

-- Speech -------------------------------------------------------------------------

test("both wording: name, tank buster, number", function()
    local ctx = stubs.load(root, {})
    ctx.ns.Speech:Announce("Blade Combo", 5)
    same(ctx.spokenMessages(), { "Blade Combo, tank buster in 5" }, "spoken")
end)

test("name wording", function()
    local ctx = stubs.load(root, { db = { phrasing = "name" } })
    ctx.ns.Speech:Announce("Blade Combo", 5)
    same(ctx.spokenMessages(), { "Blade Combo in 5" }, "spoken")
end)

test("generic wording ignores the ability name", function()
    local ctx = stubs.load(root, { db = { phrasing = "generic" } })
    ctx.ns.Speech:Announce("Blade Combo", 5)
    same(ctx.spokenMessages(), { "Tank buster in 5" }, "spoken")
end)

test("a missing name falls back to the generic phrase", function()
    local ctx = stubs.load(root, {})
    ctx.ns.Speech:Announce(nil, 5)
    same(ctx.spokenMessages(), { "Tank buster in 5" }, "spoken")
end)

test("nil seconds drops the number", function()
    local ctx = stubs.load(root, {})
    ctx.ns.Speech:Announce("Blade Combo", nil)
    same(ctx.spokenMessages(), { "Blade Combo, tank buster" }, "spoken")
end)

test("zero seconds says now", function()
    local ctx = stubs.load(root, {})
    ctx.ns.Speech:Announce("Blade Combo", 0)
    same(ctx.spokenMessages(), { "Blade Combo now" }, "spoken")
end)

test("Count speaks a bare number", function()
    local ctx = stubs.load(root, {})
    ctx.ns.Speech:Count(3)
    same(ctx.spokenMessages(), { "3" }, "spoken")
end)

test("an installed saved voice is used", function()
    local ctx = stubs.load(root, { db = { voiceID = 1 } })
    ctx.ns.Speech:Count(1)
    eq(ctx.spoken[1].id, 1, "voice id")
end)

test("a saved voice that isn't installed falls back and warns once", function()
    local ctx = stubs.load(root, { db = { voiceID = 99 } })
    ctx.ns.Speech:Count(2)
    ctx.ns.Speech:Count(1)
    eq(ctx.spoken[1].id, 0, "fallback voice")
    eq(ctx.spoken[2].id, 0, "fallback voice again")
    eq(ctx.countPrinted("isn't installed on this computer"), 1, "one warning")
end)

test("a saved voice is trusted while the voice list is empty", function()
    local ctx = stubs.load(root, { db = { voiceID = 99 }, voices = {} })
    ctx.ns.Speech:Count(2)
    eq(ctx.spoken[1].id, 99, "saved id used")
    eq(ctx.countPrinted("isn't installed"), 0, "no warning")
end)

test("speech errors are reported once and never escape", function()
    local ctx = stubs.load(root, { speakError = true })
    ctx.ns.Speech:Count(2)
    ctx.ns.Speech:Count(1)
    eq(ctx.countPrinted("Couldn't speak through text-to-speech"), 1, "one report")
end)

-- Watcher: callouts and countdown ------------------------------------------------

test("a non-tank ability is ignored", function()
    local ctx = stubs.load(root, {})
    startBar(ctx, stubs.module({}, { [BLADE] = "Blade Combo" }), BLADE, nil, 12)
    ctx.advance(12)
    same(ctx.spokenMessages(), {}, "spoken")
end)

test("a tank ability is called out at the lead time, then counted down", function()
    local ctx = stubs.load(root, {})
    startBar(ctx, bladeModule(), BLADE, nil, 12)
    ctx.advance(12)
    local msgs = ctx.spokenMessages()
    same(msgs, { "Blade Combo, tank buster in 5", "3", "2", "1" }, "spoken")
    near(ctx.spoken[1].t, 7, 0.2, "callout time")
    near(ctx.spoken[2].t, 9, 0.2, "count 3 time")
end)

test("when the countdown covers the callout, the callout has no number", function()
    local ctx = stubs.load(root, { db = { countFrom = 5, lead = 5 } })
    startBar(ctx, bladeModule(), BLADE, nil, 20)
    ctx.advance(20)
    same(ctx.spokenMessages(), { "Blade Combo, tank buster", "5", "4", "3", "2", "1" }, "spoken")
end)

test("countdown off means only the callout", function()
    local ctx = stubs.load(root, { db = { countFrom = 0 } })
    startBar(ctx, bladeModule(), BLADE, nil, 12)
    ctx.advance(12)
    same(ctx.spokenMessages(), { "Blade Combo, tank buster in 5" }, "spoken")
end)

test("the extra list covers abilities LittleWigs doesn't flag", function()
    local ctx = stubs.load(root, { db = { extra = { [MAUL] = true } } })
    startBar(ctx, stubs.module({}, { [MAUL] = "Savage Maul" }), MAUL, "Savage Maul", 12)
    ctx.advance(12)
    truthy(#ctx.spoken > 0, "Savage Maul spoken")
    eq(ctx.spoken[1].msg, "Savage Maul, tank buster in 5", "wording")
end)

test("onlyAsTank keeps a non-tank quiet", function()
    local ctx = stubs.load(root, { tank = false })
    startBar(ctx, bladeModule(), BLADE, nil, 12)
    ctx.advance(12)
    same(ctx.spokenMessages(), {}, "spoken")
end)

test("turning onlyAsTank off lets a non-tank hear", function()
    local ctx = stubs.load(root, { tank = false, db = { onlyAsTank = false } })
    startBar(ctx, bladeModule(), BLADE, nil, 12)
    ctx.advance(12)
    eq(ctx.spoken[1].msg, "Blade Combo, tank buster in 5", "callout")
end)

test("a disabled addon is silent", function()
    local ctx = stubs.load(root, { db = { enabled = false } })
    startBar(ctx, bladeModule(), BLADE, nil, 12)
    ctx.advance(12)
    same(ctx.spokenMessages(), {}, "spoken")
end)

test("bars under one second are ignored", function()
    local ctx = stubs.load(root, {})
    startBar(ctx, bladeModule(), BLADE, nil, 0.5)
    ctx.advance(2)
    same(ctx.spokenMessages(), {}, "spoken")
end)

test("secret bar text is ignored without an error", function()
    local ctx = stubs.load(root, {})
    ctx.emit("BigWigs_StartBar", bladeModule(), BLADE, stubs.secret("Blade Combo"), 12)
    ctx.advance(12)
    same(ctx.spokenMessages(), {}, "spoken")
end)

test("a repeat start inside the suppression window is ignored", function()
    local ctx = stubs.load(root, {})
    local mod = bladeModule()
    startBar(ctx, mod, BLADE, nil, 12)
    ctx.advance(7)               -- callout happens here (7s in)
    ctx.advance(6)               -- 6s after the callout: inside the lead + 4 window
    startBar(ctx, mod, BLADE, nil, 12)
    ctx.advance(20)
    eq(#ctx.spoken, 4, "one callout plus its three counts")
end)

test("the same ability is called out again after the window", function()
    local ctx = stubs.load(root, {})
    local mod = bladeModule()
    startBar(ctx, mod, BLADE, nil, 12)
    ctx.advance(20)              -- first bar finished
    startBar(ctx, mod, BLADE, nil, 12)
    ctx.advance(12)
    local callouts = 0
    for _, m in ipairs(ctx.spokenMessages()) do
        if m == "Blade Combo, tank buster in 5" then callouts = callouts + 1 end
    end
    eq(callouts, 2, "two callouts")
end)

test("a stopped bar is not announced", function()
    local ctx = stubs.load(root, {})
    local mod = bladeModule()
    startBar(ctx, mod, BLADE, nil, 12)
    ctx.emit("BigWigs_StopBar", mod, "Blade Combo")
    ctx.advance(12)
    same(ctx.spokenMessages(), {}, "spoken")
end)

test("a paused bar does not count down until resumed", function()
    local ctx = stubs.load(root, {})
    local mod = bladeModule()
    startBar(ctx, mod, BLADE, nil, 12)
    ctx.advance(6)                                -- remaining 6, not yet called out
    ctx.emit("BigWigs_PauseBar", mod, "Blade Combo")
    ctx.advance(10)
    same(ctx.spokenMessages(), {}, "nothing while paused")
    ctx.emit("BigWigs_ResumeBar", mod, "Blade Combo")
    ctx.advance(2)
    eq(ctx.spoken[1].msg, "Blade Combo, tank buster in 5", "callout after resume")
end)

test("leaving the boss clears its bars", function()
    local ctx = stubs.load(root, {})
    local mod = bladeModule()
    startBar(ctx, mod, BLADE, nil, 12)
    ctx.emit("BigWigs_OnBossDisable", mod)
    ctx.advance(12)
    same(ctx.spokenMessages(), {}, "spoken")
end)

test("the countdown ticker stops when no bars are active", function()
    local ctx = stubs.load(root, {})
    startBar(ctx, bladeModule(), BLADE, nil, 12)
    truthy(ctx.ticker.scripts.OnUpdate ~= nil, "running while a bar is active")
    ctx.advance(20)
    eq(ctx.ticker.scripts.OnUpdate, nil, "stopped after the bar ends")
end)

test("/hu test speaks even when the addon is disabled", function()
    local ctx = stubs.load(root, { db = { enabled = false } })
    SlashCmdList.HEADSUP("test")
    ctx.advance(10)
    eq(ctx.spoken[1].msg, "Blade Combo, tank buster in 5", "test callout")
    eq(ctx.spoken[#ctx.spoken].msg, "1", "test countdown finishes")
end)

-- Options window ---------------------------------------------------------------

local function openWindow(ctx)
    SlashCmdList.HEADSUP("")
    return _G.HeadsUpOptionsFrame
end

local function findWidget(ctx, pred)
    for _, f in ipairs(ctx.frames) do
        if pred(f) then return f end
    end
end

test("the preview matches what is spoken with default settings", function()
    local ctx = stubs.load(root, {})
    openWindow(ctx)
    local preview = findWidget(ctx, function(f)
        return f.kind == "FontString" and type(f.text) == "string" and f.text:find("^\"")
    end)
    truthy(preview, "preview text")
    eq(preview.text, "\"Blade Combo, tank buster in 5...  3, 2, 1\"", "preview")
end)

test("adding a spell in the options box updates the extra list", function()
    local ctx = stubs.load(root, { db = { extra = {} } })
    openWindow(ctx)
    local box = findWidget(ctx, function(f) return f.kind == "EditBox" end)
    box.text = "270487"
    box.scripts.OnEnterPressed(box)
    eq(ctx.db.extra[270487], true, "added")
end)

test("the voice menu shows a saved voice that isn't installed here", function()
    local ctx = stubs.load(root, { db = { voiceID = 99 } })
    openWindow(ctx)
    local dropdowns = {}
    for _, f in ipairs(ctx.frames) do
        if f.kind == "DropdownButton" then dropdowns[#dropdowns + 1] = f end
    end
    local voice = dropdowns[2]
    local labels = {}
    local root_ = { CreateRadio = function(_, text) labels[#labels + 1] = text end }
    voice.menuFn(voice, root_)
    local found = false
    for _, l in ipairs(labels) do if l == "Saved voice (not installed here)" then found = true end end
    truthy(found, "menu lists the saved voice")
end)

-- Runner -------------------------------------------------------------------------

local passed, failed = 0, {}
for _, t in ipairs(tests) do
    local ok, err = pcall(t.fn)
    if ok then
        passed = passed + 1
        io.write("PASS  ", t.name, "\n")
    else
        failed[#failed + 1] = t.name
        io.write("FAIL  ", t.name, "\n      ", tostring(err), "\n")
    end
end
io.write(("\n%d passed, %d failed\n"):format(passed, #failed))
os.exit(#failed == 0 and 0 or 1)
