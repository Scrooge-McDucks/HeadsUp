-- Watcher: which BigWigs bars become callouts, and their countdown timing.
local H = dofile(TESTS_DIR .. "/wow_stub.lua")

local BLADE, MAUL = 1, 2

local function bladeModule()
    return H.module({ [BLADE] = "TANK_HEALER" }, { [BLADE] = "Blade Combo", [MAUL] = "Savage Maul" })
end

local function startBar(ctx, module, key, text, time, eventId)
    ctx.emit("BigWigs_StartBar", module, key, text or "Blade Combo", time, nil, false, time, nil, eventId)
end

local function same(name, got, want)
    local ok = #got == #want
    for i = 1, #want do if got[i] ~= want[i] then ok = false end end
    H.check(name, ok, "got " .. table.concat(got, " | "))
end

local function countCallouts(ctx, text)
    local n = 0
    for _, m in ipairs(ctx.spokenMessages()) do if m == text then n = n + 1 end end
    return n
end

H.section("Which bars count")

H.try("a non-tank ability is ignored", function()
    local ctx = H.newEnv()
    startBar(ctx, H.module({}, { [BLADE] = "Blade Combo" }), BLADE, nil, 12)
    ctx.advance(12)
    same("spoken", ctx.spokenMessages(), {})
end)

H.try("the extra list covers abilities LittleWigs doesn't flag", function()
    local ctx = H.newEnv({ db = { extra = { [MAUL] = true } } })
    startBar(ctx, H.module({}, { [MAUL] = "Savage Maul" }), MAUL, "Savage Maul", 12)
    ctx.advance(12)
    H.eq("wording", ctx.spoken[1] and ctx.spoken[1].msg, "Savage Maul, tank buster in 5")
end)

H.try("onlyAsTank keeps a non-tank quiet", function()
    local ctx = H.newEnv({ tank = false })
    startBar(ctx, bladeModule(), BLADE, nil, 12)
    ctx.advance(12)
    same("spoken", ctx.spokenMessages(), {})
end)

H.try("turning onlyAsTank off lets a non-tank hear", function()
    local ctx = H.newEnv({ tank = false, db = { onlyAsTank = false } })
    startBar(ctx, bladeModule(), BLADE, nil, 12)
    ctx.advance(12)
    H.eq("callout", ctx.spoken[1] and ctx.spoken[1].msg, "Blade Combo, tank buster in 5")
end)

H.try("a disabled addon is silent", function()
    local ctx = H.newEnv({ db = { enabled = false } })
    startBar(ctx, bladeModule(), BLADE, nil, 12)
    ctx.advance(12)
    same("spoken", ctx.spokenMessages(), {})
end)

H.try("bars under one second are ignored", function()
    local ctx = H.newEnv()
    startBar(ctx, bladeModule(), BLADE, nil, 0.5)
    ctx.advance(2)
    same("spoken", ctx.spokenMessages(), {})
end)

H.try("secret bar text is ignored without an error", function()
    local ctx = H.newEnv()
    ctx.emit("BigWigs_StartBar", bladeModule(), BLADE, H.secret("Blade Combo"), 12)
    ctx.advance(12)
    same("spoken", ctx.spokenMessages(), {})
end)

H.section("Callout and countdown")

H.try("a tank ability is called out at the lead time, then counted down", function()
    local ctx = H.newEnv()
    startBar(ctx, bladeModule(), BLADE, nil, 12)
    ctx.advance(12)
    same("spoken", ctx.spokenMessages(), { "Blade Combo, tank buster in 5", "3", "2", "1" })
    H.check("callout at about 7s", math.abs(ctx.spoken[1].t - 7) <= 0.2, ctx.spoken[1].t)
    H.check("count 3 at about 9s", math.abs(ctx.spoken[2].t - 9) <= 0.2, ctx.spoken[2].t)
end)

H.try("when the countdown covers the callout, the callout has no number", function()
    local ctx = H.newEnv({ db = { countFrom = 5, lead = 5 } })
    startBar(ctx, bladeModule(), BLADE, nil, 20)
    ctx.advance(20)
    same("spoken", ctx.spokenMessages(), { "Blade Combo, tank buster", "5", "4", "3", "2", "1" })
end)

H.try("countdown off means only the callout", function()
    local ctx = H.newEnv({ db = { countFrom = 0 } })
    startBar(ctx, bladeModule(), BLADE, nil, 12)
    ctx.advance(12)
    same("spoken", ctx.spokenMessages(), { "Blade Combo, tank buster in 5" })
end)

H.try("the Count down switch turns the countdown off and keeps its start", function()
    local ctx = H.newEnv({ db = { countdown = false } })
    startBar(ctx, bladeModule(), BLADE, nil, 12)
    ctx.advance(12)
    same("spoken", ctx.spokenMessages(), { "Blade Combo, tank buster in 5" })
    H.eq("start kept", ctx.db.countFrom, 3)
end)

H.try("name only, no seconds, no countdown: just the ability name at the lead time", function()
    local ctx = H.newEnv({ db = { phrasing = "name", sayTime = false, countdown = false } })
    startBar(ctx, bladeModule(), BLADE, nil, 12)
    ctx.advance(12)
    same("spoken", ctx.spokenMessages(), { "Blade Combo" })
    H.check("callout at about 7s", math.abs(ctx.spoken[1].t - 7) <= 0.2, ctx.spoken[1].t)
end)

H.try("no seconds, with countdown", function()
    local ctx = H.newEnv({ db = { phrasing = "name", sayTime = false } })
    startBar(ctx, bladeModule(), BLADE, nil, 12)
    ctx.advance(12)
    same("spoken", ctx.spokenMessages(), { "Blade Combo", "3", "2", "1" })
end)

H.section("Repeats, pauses and clearing")

H.try("a repeat start inside the suppression window is ignored", function()
    local ctx = H.newEnv()
    local mod = bladeModule()
    startBar(ctx, mod, BLADE, nil, 12)
    ctx.advance(7)                     -- callout happens here
    ctx.advance(6)                     -- 6s later: inside the lead + 4 window
    startBar(ctx, mod, BLADE, nil, 12)
    ctx.advance(20)
    H.eq("one callout plus its three counts", #ctx.spoken, 4)
end)

H.try("the same ability is called out again after the window", function()
    local ctx = H.newEnv()
    local mod = bladeModule()
    startBar(ctx, mod, BLADE, nil, 12)
    ctx.advance(20)                    -- first bar finished
    startBar(ctx, mod, BLADE, nil, 12)
    ctx.advance(12)
    H.eq("two callouts", countCallouts(ctx, "Blade Combo, tank buster in 5"), 2)
end)

H.try("a stopped bar is not announced", function()
    local ctx = H.newEnv()
    local mod = bladeModule()
    startBar(ctx, mod, BLADE, nil, 12)
    ctx.emit("BigWigs_StopBar", mod, "Blade Combo")
    ctx.advance(12)
    same("spoken", ctx.spokenMessages(), {})
end)

H.try("a paused bar does not count down until resumed", function()
    local ctx = H.newEnv()
    local mod = bladeModule()
    startBar(ctx, mod, BLADE, nil, 12)
    ctx.advance(6)                     -- remaining 6, not yet called out
    ctx.emit("BigWigs_PauseBar", mod, "Blade Combo")
    ctx.advance(10)
    same("nothing while paused", ctx.spokenMessages(), {})
    ctx.emit("BigWigs_ResumeBar", mod, "Blade Combo")
    ctx.advance(2)
    H.eq("callout after resume", ctx.spoken[1] and ctx.spoken[1].msg, "Blade Combo, tank buster in 5")
end)

H.try("leaving the boss clears its bars", function()
    local ctx = H.newEnv()
    local mod = bladeModule()
    startBar(ctx, mod, BLADE, nil, 12)
    ctx.emit("BigWigs_OnBossDisable", mod)
    ctx.advance(12)
    same("spoken", ctx.spokenMessages(), {})
end)

H.try("the countdown ticker stops when no bars are active", function()
    local ctx = H.newEnv()
    startBar(ctx, bladeModule(), BLADE, nil, 12)
    H.check("running while a bar is active", ctx.ticker.scripts.OnUpdate ~= nil)
    ctx.advance(20)
    H.eq("stopped after the bar ends", ctx.ticker.scripts.OnUpdate, nil)
end)

H.section("/hu test")

H.try("/hu test speaks even when the addon is disabled", function()
    local ctx = H.newEnv({ db = { enabled = false } })
    SlashCmdList.HEADSUP("test")
    ctx.advance(10)
    H.eq("test callout", ctx.spoken[1] and ctx.spoken[1].msg, "Blade Combo, tank buster in 5")
    H.eq("test countdown finishes", ctx.spoken[#ctx.spoken] and ctx.spoken[#ctx.spoken].msg, "1")
end)

H.report()
