-------------------------------------------------------------------------------
-- test_integration.lua — TOC, files on disk, and a full run through the addon
-------------------------------------------------------------------------------
local H = dofile(TESTS_DIR .. "/wow_stub.lua")

local function readFile(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local tocFiles = H.tocFiles

-- Lua files in the addon folder. run_tests.py lists the folder and passes it in, so
-- this test never needs io.popen (which not every Lua build provides).
local function sourceFiles()
  local files = {}
  for i, name in ipairs(SOURCE_FILES or {}) do files[i] = name end
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
  H.check("found source files", #found > 0, "run_tests.py did not pass SOURCE_FILES")
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
