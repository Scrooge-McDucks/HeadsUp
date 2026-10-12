-------------------------------------------------------------------------------
-- options.lua — Options window (/hu)
-- A standalone, movable window. Also listed under Options > AddOns with a
-- button that opens it. Nothing here shows during a fight unless you open it.
-------------------------------------------------------------------------------
local _, NS = ...

NS.Options = {}
NS.Options.frame = nil

local refreshers = {}  -- one function per widget, re-reads its saved value

local ipairs        = ipairs
local pairs         = pairs
local tonumber      = tonumber
local tostring      = tostring
local math_floor    = math.floor
local math_max      = math.max
local math_min      = math.min
local string_format = string.format
local table_concat  = table.concat
local table_sort    = table.sort

--- What the voice will say with the current settings.
local function SampleLine()
  local db = NS.Data.db
  local sample = NS.Config.SAMPLE_ABILITY
  local covers = NS.Watcher:CountCoversCallout()
  local bare = covers or not db.sayTime
  local first
  if db.phrasing == "both" then
    first = bare and (sample .. ", tank buster") or string_format("%s, tank buster in %d", sample, db.lead)
  elseif db.phrasing == "name" then
    first = bare and sample or string_format("%s in %d", sample, db.lead)
  else
    first = bare and "Tank buster" or string_format("Tank buster in %d", db.lead)
  end
  local nums = {}
  local from = NS.Data:CountFrom()
  local start = covers and from or math_min(from, db.lead - 1)
  for n = start, 1, -1 do nums[#nums + 1] = tostring(n) end
  if #nums > 0 then first = first .. "...  " .. table_concat(nums, ", ") end
  return "\"" .. first .. "\""
end

local function RefreshAll()
  for _, fn in ipairs(refreshers) do fn() end
end

-------------------------------------------------------------------------------
-- Widgets
-------------------------------------------------------------------------------

local function CreateLabel(parent, text, x, y, font)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetJustifyH("LEFT")
  fs:SetText(text)
  return fs
end

local function CreateCheckbox(parent, text, tooltip, key, x, y)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(26, 26)
  cb:SetPoint("TOPLEFT", x - 4, y)
  local fs = CreateLabel(parent, text, x + 24, y - 6, "GameFontHighlight")
  cb:SetScript("OnClick", function(self)
    NS.Data.db[key] = self:GetChecked() and true or false
    RefreshAll()
  end)
  cb:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(text, 1, 1, 1)
    GameTooltip:AddLine(tooltip, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  cb:SetScript("OnLeave", GameTooltip_Hide)
  refreshers[#refreshers + 1] = function() cb:SetChecked(NS.Data.db[key]) end
  return cb, fs
end

local function CreateSlider(parent, text, key, minV, maxV, step, x, y)
  local width = NS.Config.WINDOW.columnWidth
  CreateLabel(parent, text, x, y)
  local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  value:SetPoint("TOPLEFT", x + width - 20, y)
  value:SetJustifyH("RIGHT")
  value:SetWidth(20)

  local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
  s:SetOrientation("HORIZONTAL")
  s:SetSize(width, 16)
  s:SetPoint("TOPLEFT", x, y - 18)
  s:SetBackdrop({
    bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 },
  })
  s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  s:SetObeyStepOnDrag(true)
  s:EnableMouseWheel(true)
  s:SetScript("OnMouseWheel", function(self, delta)
    self:SetValue(math_max(minV, math_min(maxV, self:GetValue() + delta * step)))
  end)
  s:SetScript("OnValueChanged", function(_, v)
    v = math_floor(v / step + 0.5) * step
    value:SetText(tostring(v))
    if NS.Data.db[key] ~= v then
      NS.Data.db[key] = v
      RefreshAll()
    end
  end)
  refreshers[#refreshers + 1] = function()
    s:SetValue(NS.Data.db[key])
    value:SetText(tostring(NS.Data.db[key]))
  end
  return s
end

--- Dropdown using the 11.0+ menu API, with a cycle-on-click fallback.
local function CreateDropdown(parent, text, x, y, getOptions, get, set)
  local width = NS.Config.WINDOW.columnWidth
  CreateLabel(parent, text, x, y)
  local ok, dd = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
  if ok and dd and dd.SetupMenu then
    dd:SetWidth(width)
    dd:SetPoint("TOPLEFT", x, y - 18)
    dd:SetupMenu(function(_, root)
      for _, o in ipairs(getOptions()) do
        root:CreateRadio(o.text, function() return get() == o.value end, function()
          set(o.value)
          RefreshAll()
        end)
      end
    end)
    refreshers[#refreshers + 1] = function() dd:GenerateMenu() end
    return dd
  end
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  b:SetPoint("TOPLEFT", x, y - 18)
  local function Current()
    local opts = getOptions()
    for i, o in ipairs(opts) do if get() == o.value then return i, opts end end
    return 1, opts
  end
  b:SetScript("OnClick", function()
    local i, opts = Current()
    set(opts[i % #opts + 1].value)
    RefreshAll()
  end)
  refreshers[#refreshers + 1] = function()
    local i, opts = Current()
    b:SetText(opts[i] and opts[i].text or "?")
  end
  return b
end

local function VoiceOptions()
  local opts = { { text = "Game default voice", value = false } }
  local voices = C_VoiceChat.GetTtsVoices and C_VoiceChat.GetTtsVoices() or {}
  local saved = NS.Data.db.voiceID
  local found = false
  for _, v in ipairs(voices) do
    opts[#opts + 1] = { text = v.name, value = v.voiceID }
    if v.voiceID == saved then found = true end
  end
  -- A voice saved on another computer: show it so the menu doesn't go blank.
  if saved and not found and #voices > 0 then
    opts[#opts + 1] = { text = "Saved voice (not installed here)", value = saved }
  end
  return opts
end

-------------------------------------------------------------------------------
-- Extra tank-buster spell list
-------------------------------------------------------------------------------

local function SpellName(id)
  local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
  return name or "Unknown spell"
end

local function BuildExtras(parent, x, y)
  local width = NS.Config.WINDOW.columnWidth
  CreateLabel(parent, "Also treat as tank busters", x, y)
  local help = CreateLabel(parent, "For abilities LittleWigs doesn't flag as tank hits.", x, y - 18, "GameFontDisableSmall")
  help:SetWidth(width)

  local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  box:SetSize(150, 22)
  box:SetPoint("TOPLEFT", x + 6, y - 38)
  box:SetAutoFocus(false)
  box:SetNumeric(true)
  box:SetMaxLetters(9)

  local add = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  add:SetSize(90, 22)
  add:SetPoint("LEFT", box, "RIGHT", 8, 0)
  add:SetText("Add spell ID")
  local function DoAdd()
    local id = tonumber(box:GetText())
    if id then
      NS.Data.db.extra[id] = true
      box:SetText("")
      box:ClearFocus()
      RefreshAll()
    end
  end
  add:SetScript("OnClick", DoAdd)
  box:SetScript("OnEnterPressed", DoAdd)
  box:SetScript("OnEscapePressed", box.ClearFocus)

  local rows = {}
  for i = 1, NS.Config.WINDOW.extraRows do
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width, 20)
    row:SetPoint("TOPLEFT", x, y - 66 - (i - 1) * 22)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.text:SetPoint("LEFT", 4, 0)
    row.text:SetWidth(width - 60)
    row.text:SetJustifyH("LEFT")
    row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.remove:SetSize(60, 18)
    row.remove:SetPoint("RIGHT")
    row.remove:SetText("Remove")
    row.remove:SetScript("OnClick", function()
      if row.id then
        NS.Data.db.extra[row.id] = nil
        RefreshAll()
      end
    end)
    rows[i] = row
  end
  local empty = CreateLabel(parent, "Nothing added.", x + 4, y - 70, "GameFontDisable")

  refreshers[#refreshers + 1] = function()
    local ids = {}
    for id in pairs(NS.Data.db.extra) do ids[#ids + 1] = id end
    table_sort(ids)
    for i, row in ipairs(rows) do
      local id = ids[i]
      row.id = id
      if id then
        row.text:SetText(string_format("%s  |cff888888%d|r", SpellName(id), id))
        row:Show()
      else
        row:Hide()
      end
    end
    empty:SetShown(#ids == 0)
  end
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------

local function Build()
  local C = NS.Config
  local win = CreateFrame("Frame", "HeadsUpOptionsFrame", UIParent, "BackdropTemplate")
  win:SetSize(C.WINDOW.width, C.WINDOW.height)
  win:SetPoint("CENTER")
  win:SetFrameStrata("DIALOG")
  win:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  win:SetMovable(true)
  win:EnableMouse(true)
  win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving)
  win:SetScript("OnDragStop", win.StopMovingOrSizing)
  win:SetClampedToScreen(true)
  win:Hide()
  tinsert(UISpecialFrames, "HeadsUpOptionsFrame") -- Esc closes it

  local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -18)
  title:SetText(C.TITLE)
  local sub = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sub:SetPoint("TOP", title, "BOTTOM", 0, -2)
  sub:SetText("Spoken tank-buster warnings from BigWigs / LittleWigs")

  local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  -- Left column: when and how it speaks.
  local L, R = C.WINDOW.leftX, C.WINDOW.rightX
  CreateCheckbox(win, "Enable callouts", "Speak tank busters during boss fights.", "enabled", L, -56)
  CreateCheckbox(win, "Only when I'm a tank", "Stay quiet unless your current specialization is a tank spec.", "onlyAsTank", L, -82)
  CreateSlider(win, "First callout (seconds before the hit)", "lead", C.LEAD_MIN, C.LEAD_MAX, 1, L, -118)
  CreateCheckbox(win, "Count down", "After the first callout, count the last seconds: \"3, 2, 1\".", "countdown", L, -164)
  CreateSlider(win, "Count down from", "countFrom", C.COUNT_MIN, C.COUNT_MAX, 1, L, -196)
  CreateDropdown(win, "Wording", L, -242, function()
    return {
      { text = "Blade Combo, tank buster in 5", value = "both" },
      { text = "Blade Combo in 5",              value = "name" },
      { text = "Tank buster in 5",              value = "generic" },
    }
  end, function() return NS.Data.db.phrasing end, function(v) NS.Data.db.phrasing = v end)
  CreateCheckbox(win, "Say the seconds", "Include \"in 5\" in the first callout. Turn off to hear just the ability name at the first callout time.", "sayTime", L, -290)
  CreateDropdown(win, "Voice", L, -324, VoiceOptions,
    function() return NS.Data.db.voiceID or false end,
    function(v) NS.Data.db.voiceID = v or nil end)
  CreateSlider(win, "Speech speed", "rate", C.RATE_MIN, C.RATE_MAX, 1, L, -376)
  CreateSlider(win, "Volume", "volume", C.VOLUME_MIN, C.VOLUME_MAX, 5, L, -422)

  -- Right column: extra spells, preview, test.
  BuildExtras(win, R, -56)

  CreateLabel(win, "You'll hear", R, -330)
  local preview = CreateLabel(win, "", R, -350, "GameFontHighlight")
  preview:SetWidth(C.WINDOW.columnWidth)
  preview:SetWordWrap(true)
  refreshers[#refreshers + 1] = function() preview:SetText(SampleLine()) end

  local test = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
  test:SetSize(150, 26)
  test:SetPoint("TOPLEFT", R, -414)
  test:SetText("Test callout")
  test:SetScript("OnClick", function() NS.Watcher:Test() end)

  local hint = CreateLabel(win, "/hu opens this window", R + 160, -420, "GameFontDisableSmall")
  hint:SetWidth(160)

  win:SetScript("OnShow", RefreshAll)
  return win
end

function NS.Options:Open()
  if not self.frame then self.frame = Build() end
  if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
  self.frame:Show()
  RefreshAll()
end

function NS.Options:Toggle()
  if self.frame and self.frame:IsShown() then self.frame:Hide() else self:Open() end
end

--- Options > AddOns > Heads Up: a short page with a button that opens the
--- window. Without the Settings API, /hu still opens the window.
function NS.Options:RegisterBlizzardOptions()
  pcall(function()
    local page = CreateFrame("Frame")
    page:SetSize(400, 200)
    local t = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText(NS.Config.TITLE)
    local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    b:SetSize(180, 26)
    b:SetPoint("TOPLEFT", 16, -48)
    b:SetText("Open Heads Up options")
    b:SetScript("OnClick", function() NS.Options:Open() end)
    local category = Settings.RegisterCanvasLayoutCategory(page, NS.Config.TITLE)
    Settings.RegisterAddOnCategory(category)
  end)
end
