-- Heads Up smoke tests: the minimum that must pass before anything is deployed.
--   lua tests/smoke.lua
-- Fast, no game needed. For the full suite, run tests/run.lua.

local root = arg[1] or "."
local stubs = dofile(root .. "/tests/stubs.lua")

local failures = 0
local function check(name, fn)
    local ok, err = pcall(fn)
    if ok then
        io.write("PASS  ", name, "\n")
    else
        failures = failures + 1
        io.write("FAIL  ", name, "\n      ", tostring(err), "\n")
    end
end

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

-- Files listed in HeadsUp.toc (ignores ## metadata, blank lines and comments).
local function tocFiles()
    local toc = assert(readFile(root .. "/HeadsUp.toc"), "HeadsUp.toc is missing")
    local files = {}
    for line in toc:gmatch("[^\r\n]+") do
        local s = line:match("^%s*(.-)%s*$")
        if s ~= "" and s:sub(1, 1) ~= "#" then
            files[#files + 1] = (s:gsub("\\", "/"))
        end
    end
    return files
end

-- Lua files actually in Sources/ (ls on Linux/macOS, dir on Windows).
local function sourceFiles()
    local p = io.popen('ls "' .. root .. '/Sources" 2>/dev/null || dir /b "' .. root .. '\\Sources"')
    local out = p:read("*a")
    p:close()
    local files = {}
    for name in out:gmatch("[^\r\n]+") do
        if name:match("%.lua$") then files[#files + 1] = "Sources/" .. name end
    end
    return files
end

check("TOC has an Interface version for the current client", function()
    local toc = assert(readFile(root .. "/HeadsUp.toc"))
    assert(toc:match("## Interface: %d+"), "no ## Interface line")
end)

check("every file listed in the TOC exists", function()
    for _, path in ipairs(tocFiles()) do
        assert(readFile(root .. "/" .. path), "TOC lists a missing file: " .. path)
    end
end)

check("every Lua source file is listed in the TOC", function()
    local listed = {}
    for _, path in ipairs(tocFiles()) do listed[path] = true end
    local found = sourceFiles()
    assert(#found > 0, "found no source files; is the working directory right?")
    for _, path in ipairs(found) do
        assert(listed[path], path .. " exists but is not in HeadsUp.toc, so the game won't load it")
    end
end)

check("every TOC Lua file compiles", function()
    for _, path in ipairs(tocFiles()) do
        if path:match("%.lua$") then
            local chunk, err = loadfile(root .. "/" .. path)
            assert(chunk, err)
        end
    end
end)

check("the addon loads with BigWigs and LittleWigs present", function()
    local ctx = stubs.load(root, { lwLoaded = true })
    assert(ctx.db, "saved variables were not created")
    assert(ctx.db.enabled ~= nil, "defaults were not applied")
end)

check("the options window opens without error", function()
    local ctx = stubs.load(root, {})
    SlashCmdList.HEADSUP("")
    assert(_G.HeadsUpOptionsFrame and _G.HeadsUpOptionsFrame:IsShown(), "window did not open")
end)

check("a full test callout runs without error", function()
    local ctx = stubs.load(root, {})
    SlashCmdList.HEADSUP("test")
    ctx.advance(10)
    assert(#ctx.spoken > 0, "test callout spoke nothing")
end)

check("a tank buster from BigWigs is spoken end to end", function()
    local ctx = stubs.load(root, {})
    local mod = stubs.module({ [1] = "TANK_HEALER" }, { [1] = "Blade Combo" })
    ctx.emit("BigWigs_StartBar", mod, 1, "Blade Combo", 12, nil, false, 12, nil, nil)
    ctx.advance(12)
    assert(#ctx.spoken >= 2, "expected a callout and at least one count")
    assert(ctx.spoken[1].msg == "Blade Combo, tank buster in 5", "wrong callout: " .. ctx.spoken[1].msg)
end)

io.write(("\n%s\n"):format(failures == 0 and "Smoke tests passed." or ("Smoke tests FAILED: " .. failures)))
os.exit(failures == 0 and 0 or 1)
