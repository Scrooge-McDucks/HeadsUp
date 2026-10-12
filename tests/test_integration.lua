-- Integration: the TOC, the files on disk, and a full run through the addon.
-- These are the checks that must pass before anything is released.
local H = dofile(TESTS_DIR .. "/wow_stub.lua")

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

-- Files listed in HeadsUp.toc (skips ## metadata, blank lines and comments).
local function tocFiles()
    local toc = readFile(ADDON_DIR .. "/HeadsUp.toc")
    local files = {}
    for line in toc:gmatch("[^\r\n]+") do
        local s = line:match("^%s*(.-)%s*$")
        if s ~= "" and s:sub(1, 1) ~= "#" and s:sub(1, 2) ~= "##" then
            files[#files + 1] = (s:gsub("\\", "/"))
        end
    end
    return files
end

-- Lua files actually in Sources/ (ls on Linux/macOS, dir on Windows).
local function sourceFiles()
    local p = io.popen('ls "' .. ADDON_DIR .. '/Sources" 2>/dev/null')
    local out = p and p:read("*a") or ""
    if p then p:close() end
    if out == "" then
        p = io.popen('dir /b "' .. ADDON_DIR .. '\\Sources"')
        out = p and p:read("*a") or ""
        if p then p:close() end
    end
    local files = {}
    for name in out:gmatch("[^\r\n]+") do
        if name:match("%.lua$") then files[#files + 1] = "Sources/" .. name end
    end
    return files
end

H.section("Table of contents")

H.try("TOC has an Interface version for the current client", function()
    H.check("## Interface line", readFile(ADDON_DIR .. "/HeadsUp.toc"):match("## Interface: %d+") ~= nil)
end)

H.try("the icon texture referenced by the TOC exists", function()
    local toc = readFile(ADDON_DIR .. "/HeadsUp.toc")
    local icon = toc:match("## IconTexture: Interface\\AddOns\\HeadsUp\\(%S+)")
    H.check("IconTexture line", icon ~= nil)
    H.check("texture file on disk", readFile(ADDON_DIR .. "/" .. icon:gsub("\\", "/") .. ".tga") ~= nil)
end)

H.try("every file listed in the TOC exists", function()
    for _, path in ipairs(tocFiles()) do
        H.check(path, readFile(ADDON_DIR .. "/" .. path) ~= nil)
    end
end)

H.try("every Lua source file is listed in the TOC", function()
    local listed = {}
    for _, path in ipairs(tocFiles()) do listed[path] = true end
    local found = sourceFiles()
    H.check("found source files", #found > 0, "is the addon folder right?")
    for _, path in ipairs(found) do
        H.check(path .. " is in the TOC", listed[path] == true,
            "exists but the game won't load it")
    end
end)

H.section("Compilation")

H.try("every TOC Lua file compiles", function()
    for _, path in ipairs(tocFiles()) do
        if path:match("%.lua$") then
            local chunk, err = loadfile(ADDON_DIR .. "/" .. path)
            H.check(path .. " compiles", chunk ~= nil, err)
        end
    end
end)

H.section("End to end")

H.try("the addon loads with BigWigs and LittleWigs present", function()
    local ctx = H.newEnv({ lwLoaded = true })
    H.check("saved variables created", ctx.db ~= nil)
    H.check("defaults applied", ctx.db and ctx.db.enabled ~= nil)
end)

H.try("the options window opens without error", function()
    local ctx = H.newEnv()
    SlashCmdList.HEADSUP("")
    H.check("window shown", _G.HeadsUpOptionsFrame ~= nil and _G.HeadsUpOptionsFrame:IsShown())
end)

H.try("a full test callout runs without error", function()
    local ctx = H.newEnv()
    SlashCmdList.HEADSUP("test")
    ctx.advance(10)
    H.check("test callout spoke", #ctx.spoken > 0)
end)

H.try("a tank buster from BigWigs is spoken end to end", function()
    local ctx = H.newEnv()
    local mod = H.module({ [1] = "TANK_HEALER" }, { [1] = "Blade Combo" })
    ctx.emit("BigWigs_StartBar", mod, 1, "Blade Combo", 12, nil, false, 12, nil, nil)
    ctx.advance(12)
    H.check("callout and counts spoken", #ctx.spoken >= 2)
    H.eq("first callout", ctx.spoken[1] and ctx.spoken[1].msg, "Blade Combo, tank buster in 5")
end)

H.report()
