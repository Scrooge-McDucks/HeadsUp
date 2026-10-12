-- Core: saved variables, secret-value helper, slash commands and login checks.
local H = dofile(TESTS_DIR .. "/wow_stub.lua")

H.section("Saved variables")

H.try("fresh saved variables get the defaults", function()
    local ctx = H.newEnv()
    H.eq("lead", ctx.db.lead, 5)
    H.eq("countFrom", ctx.db.countFrom, 3)
    H.eq("onlyAsTank", ctx.db.onlyAsTank, true)
    H.eq("Savage Maul default", ctx.db.extra[1303488], true)
end)

H.try("existing saved values are kept", function()
    local ctx = H.newEnv({ db = { lead = 7 } })
    H.eq("lead kept", ctx.db.lead, 7)
    H.eq("countFrom filled in", ctx.db.countFrom, 3)
end)

H.try("a removed default spell stays removed", function()
    local ctx = H.newEnv({ db = { extra = {} } })
    H.eq("Savage Maul", ctx.db.extra[1303488], nil)
end)

H.section("Secret values")

H.try("Readable rejects secret values and nil", function()
    local ctx = H.newEnv()
    H.eq("secret", ctx.ns.Readable(H.secret("x")), nil)
    H.eq("nil", ctx.ns.Readable(nil), nil)
    H.eq("plain string", ctx.ns.Readable("x"), "x")
    H.eq("plain number", ctx.ns.Readable(7), 7)
end)

H.section("Slash commands")

H.try("/hu lead clamps to 2..10 and floors", function()
    local ctx = H.newEnv()
    SlashCmdList.HEADSUP("lead 1");   H.eq("low clamp", ctx.db.lead, 2)
    SlashCmdList.HEADSUP("lead 50");  H.eq("high clamp", ctx.db.lead, 10)
    SlashCmdList.HEADSUP("lead 7.6"); H.eq("floor", ctx.db.lead, 7)
end)

H.try("/hu count clamps to 0..10, and 0 turns countdown off", function()
    local ctx = H.newEnv()
    SlashCmdList.HEADSUP("count 99"); H.eq("high clamp", ctx.db.countFrom, 10)
    SlashCmdList.HEADSUP("count -3"); H.eq("low clamp", ctx.db.countFrom, 0)
    H.eq("off message", ctx.countPrinted("Countdown off"), 1)
end)

H.try("/hu add and remove change the extra list", function()
    local ctx = H.newEnv({ db = { extra = {} } })
    SlashCmdList.HEADSUP("add 270487")
    H.eq("added", ctx.db.extra[270487], true)
    SlashCmdList.HEADSUP("remove 270487")
    H.eq("removed", ctx.db.extra[270487], nil)
end)

H.try("/hu add without a number prints usage and changes nothing", function()
    local ctx = H.newEnv({ db = { extra = {} } })
    SlashCmdList.HEADSUP("add abc")
    H.eq("extra list unchanged", next(ctx.db.extra), nil)
    H.eq("usage line", ctx.countPrinted("Usage: /hu add <spellID>"), 1)
end)

H.try("/hu remove without a number prints usage", function()
    local ctx = H.newEnv()
    SlashCmdList.HEADSUP("remove")
    H.eq("usage line", ctx.countPrinted("Usage: /hu remove <spellID>"), 1)
end)

H.try("/hu toggle flips enabled", function()
    local ctx = H.newEnv()
    SlashCmdList.HEADSUP("toggle"); H.eq("off", ctx.db.enabled, false)
    SlashCmdList.HEADSUP("toggle"); H.eq("on", ctx.db.enabled, true)
end)

H.section("Login")

H.try("login warns when LittleWigs is missing", function()
    local ctx = H.newEnv({ lwLoaded = false })
    ctx.fire("PLAYER_LOGIN")
    H.eq("warning", ctx.countPrinted("LittleWigs isn't loaded"), 1)
end)

H.try("login is silent when LittleWigs is loaded", function()
    local ctx = H.newEnv({ lwLoaded = true })
    ctx.fire("PLAYER_LOGIN")
    H.eq("no warning", ctx.countPrinted("LittleWigs"), 0)
end)

H.report()
