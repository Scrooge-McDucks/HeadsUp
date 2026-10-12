-------------------------------------------------------------------------------
-- test_options.lua — options window preview, spell box and voice menu
-------------------------------------------------------------------------------
local H = dofile(TESTS_DIR .. "/wow_stub.lua")

H.section("Options window")

H.try("the preview matches what is spoken with default settings", function()
  local ctx = H.newEnv()
  SlashCmdList.HEADSUP("")
  local preview = ctx.findWidget(function(f)
    return f.kind == "FontString" and type(f.text) == "string" and f.text:find("^\"")
  end)
  H.check("preview text exists", preview ~= nil)
  H.eq("preview", preview and preview.text, "\"Blade Combo, tank buster in 5...  3, 2, 1\"")
end)

H.try("the preview drops the seconds and countdown when both are off", function()
  local ctx = H.newEnv({ db = { phrasing = "name", sayTime = false, countdown = false } })
  SlashCmdList.HEADSUP("")
  local preview = ctx.findWidget(function(f)
    return f.kind == "FontString" and type(f.text) == "string" and f.text:find("^\"")
  end)
  H.eq("preview", preview and preview.text, "\"Blade Combo\"")
end)

H.try("adding a spell in the options box updates the extra list", function()
  local ctx = H.newEnv({ db = { extra = {} } })
  SlashCmdList.HEADSUP("")
  local box = ctx.findWidget(function(f) return f.kind == "EditBox" end)
  box.text = "270487"
  box.scripts.OnEnterPressed(box)
  H.eq("added", ctx.db.extra[270487], true)
end)

H.try("the voice menu shows a saved voice that isn't installed here", function()
  local ctx = H.newEnv({ db = { voiceID = 99 } })
  SlashCmdList.HEADSUP("")
  local dropdowns = {}
  for _, f in ipairs(ctx.frames) do
    if f.kind == "DropdownButton" then dropdowns[#dropdowns + 1] = f end
  end
  local voice = dropdowns[2]
  local labels = {}
  local menu = { CreateRadio = function(_, text) labels[#labels + 1] = text end }
  voice.menuFn(voice, menu)
  local found = false
  for _, l in ipairs(labels) do if l == "Saved voice (not installed here)" then found = true end end
  H.check("menu lists the saved voice", found)
end)

H.report()
