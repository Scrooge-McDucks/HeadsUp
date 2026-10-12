-- Speech: wording, the countdown numbers, voice choice and speech errors.
local H = dofile(TESTS_DIR .. "/wow_stub.lua")

local function same(name, got, want)
    local ok = #got == #want
    for i = 1, #want do if got[i] ~= want[i] then ok = false end end
    H.check(name, ok, "got " .. table.concat(got, " | "))
end

H.section("Wording")

H.try("both wording: name, tank buster, number", function()
    local ctx = H.newEnv()
    ctx.ns.Speech:Announce("Blade Combo", 5)
    same("spoken", ctx.spokenMessages(), { "Blade Combo, tank buster in 5" })
end)

H.try("name wording", function()
    local ctx = H.newEnv({ db = { phrasing = "name" } })
    ctx.ns.Speech:Announce("Blade Combo", 5)
    same("spoken", ctx.spokenMessages(), { "Blade Combo in 5" })
end)

H.try("generic wording ignores the ability name", function()
    local ctx = H.newEnv({ db = { phrasing = "generic" } })
    ctx.ns.Speech:Announce("Blade Combo", 5)
    same("spoken", ctx.spokenMessages(), { "Tank buster in 5" })
end)

H.try("a missing name falls back to the generic phrase", function()
    local ctx = H.newEnv()
    ctx.ns.Speech:Announce(nil, 5)
    same("spoken", ctx.spokenMessages(), { "Tank buster in 5" })
end)

H.try("nil seconds drops the number", function()
    local ctx = H.newEnv()
    ctx.ns.Speech:Announce("Blade Combo", nil)
    same("spoken", ctx.spokenMessages(), { "Blade Combo, tank buster" })
end)

H.try("Say the seconds off drops the number", function()
    local ctx = H.newEnv({ db = { sayTime = false } })
    ctx.ns.Speech:Announce("Blade Combo", 5)
    same("spoken", ctx.spokenMessages(), { "Blade Combo, tank buster" })
end)

H.try("Say the seconds off still says now for a late callout", function()
    local ctx = H.newEnv({ db = { sayTime = false } })
    ctx.ns.Speech:Announce("Blade Combo", 0)
    same("spoken", ctx.spokenMessages(), { "Blade Combo now" })
end)

H.try("zero seconds says now", function()
    local ctx = H.newEnv()
    ctx.ns.Speech:Announce("Blade Combo", 0)
    same("spoken", ctx.spokenMessages(), { "Blade Combo now" })
end)

H.try("Count speaks a bare number", function()
    local ctx = H.newEnv()
    ctx.ns.Speech:Count(3)
    same("spoken", ctx.spokenMessages(), { "3" })
end)

H.section("Voice")

H.try("an installed saved voice is used", function()
    local ctx = H.newEnv({ db = { voiceID = 1 } })
    ctx.ns.Speech:Count(1)
    H.eq("voice id", ctx.spoken[1].id, 1)
end)

H.try("a saved voice that isn't installed falls back and warns once", function()
    local ctx = H.newEnv({ db = { voiceID = 99 } })
    ctx.ns.Speech:Count(2)
    ctx.ns.Speech:Count(1)
    H.eq("fallback voice", ctx.spoken[1].id, 0)
    H.eq("fallback voice again", ctx.spoken[2].id, 0)
    H.eq("one warning", ctx.countPrinted("isn't installed on this computer"), 1)
end)

H.try("a saved voice is trusted while the voice list is empty", function()
    local ctx = H.newEnv({ db = { voiceID = 99 }, voices = {} })
    ctx.ns.Speech:Count(2)
    H.eq("saved id used", ctx.spoken[1].id, 99)
    H.eq("no warning", ctx.countPrinted("isn't installed"), 0)
end)

H.section("Errors")

H.try("speech errors are reported once and never escape", function()
    local ctx = H.newEnv({ speakError = true })
    ctx.ns.Speech:Count(2)
    ctx.ns.Speech:Count(1)
    H.eq("one report", ctx.countPrinted("Couldn't speak through text-to-speech"), 1)
end)

H.report()
