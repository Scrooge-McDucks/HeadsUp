-- Heads Up: Options window (/hu)
-- A standalone, movable window. Also listed under Options > AddOns with a
-- button that opens it. Nothing here shows during a fight unless you open it.

local _, ns = ...
local O = {}
ns.Config = O

local win
local refreshers = {}

local SAMPLE = "Blade Combo"

-- What the voice will say with the current settings.
local function sampleLine()
    local db = ns.db
    local covers = ns.Watcher.CountCoversCallout()
    local first
    if db.phrasing == "both" then
        first = covers and (SAMPLE .. ", tank buster") or ("%s, tank buster in %d"):format(SAMPLE, db.lead)
    elseif db.phrasing == "name" then
        first = covers and SAMPLE or ("%s in %d"):format(SAMPLE, db.lead)
    else
        first = covers and "Tank buster" or ("Tank buster in %d"):format(db.lead)
    end
    local nums = {}
    local start = covers and db.countFrom or math.min(db.countFrom, db.lead - 1)
    for n = start, 1, -1 do nums[#nums + 1] = tostring(n) end
    if #nums > 0 then first = first .. "...  " .. table.concat(nums, ", ") end
    return "\"" .. first .. "\""
end

local function refreshAll()
    for _, fn in ipairs(refreshers) do fn() end
end

-- Widgets ----------------------------------------------------------------------

local function label(parent, text, x, y, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

local function checkbox(parent, text, tip, key, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", x - 4, y)
    local fs = label(parent, text, x + 24, y - 6, "GameFontHighlight")
    cb:SetScript("OnClick", function(self)
        ns.db[key] = self:GetChecked() and true or false
        refreshAll()
    end)
    cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1)
        GameTooltip:AddLine(tip, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", GameTooltip_Hide)
    refreshers[#refreshers + 1] = function() cb:SetChecked(ns.db[key]) end
    return cb, fs
end

local function slider(parent, text, key, minV, maxV, step, fmt, x, y)
    label(parent, text, x, y)
    local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    value:SetPoint("TOPLEFT", x + 300, y)
    value:SetJustifyH("RIGHT")
    value:SetWidth(20)

    local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetSize(320, 16)
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
        self:SetValue(math.max(minV, math.min(maxV, self:GetValue() + delta * step)))
    end)
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        value:SetText(fmt(v))
        if ns.db[key] ~= v then
            ns.db[key] = v
            refreshAll()
        end
    end)
    refreshers[#refreshers + 1] = function()
        s:SetValue(ns.db[key])
        value:SetText(fmt(ns.db[key]))
    end
    return s
end

-- Dropdown using the 11.0+ menu API, with a cycle-on-click fallback.
local function dropdown(parent, text, x, y, getOptions, get, set)
    label(parent, text, x, y)
    local ok, dd = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    if ok and dd and dd.SetupMenu then
        dd:SetWidth(320)
        dd:SetPoint("TOPLEFT", x, y - 18)
        dd:SetupMenu(function(_, root)
            for _, o in ipairs(getOptions()) do
                root:CreateRadio(o.text, function() return get() == o.value end, function()
                    set(o.value)
                    refreshAll()
                end)
            end
        end)
        refreshers[#refreshers + 1] = function() dd:GenerateMenu() end
        return dd
    end
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(320, 22)
    b:SetPoint("TOPLEFT", x, y - 18)
    local function current()
        local opts = getOptions()
        for i, o in ipairs(opts) do if get() == o.value then return i, opts end end
        return 1, opts
    end
    b:SetScript("OnClick", function()
        local i, opts = current()
        set(opts[i % #opts + 1].value)
        refreshAll()
    end)
    refreshers[#refreshers + 1] = function()
        local i, opts = current()
        b:SetText(opts[i] and opts[i].text or "?")
    end
    return b
end

local function voiceOptions()
    local opts = { { text = "Game default voice", value = false } }
    local voices = C_VoiceChat.GetTtsVoices and C_VoiceChat.GetTtsVoices() or {}
    for _, v in ipairs(voices) do
        opts[#opts + 1] = { text = v.name, value = v.voiceID }
    end
    return opts
end

-- Extra tank-buster spell list -----------------------------------------------------

local EXTRA_ROWS = 8

local function spellName(id)
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    return name or "Unknown spell"
end

local function buildExtras(parent, x, y)
    label(parent, "Also treat as tank busters", x, y)
    local help = label(parent, "For abilities LittleWigs doesn't flag as tank hits.", x, y - 18, "GameFontDisableSmall")
    help:SetWidth(320)

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
    local function doAdd()
        local id = tonumber(box:GetText())
        if id then
            ns.db.extra[id] = true
            box:SetText("")
            box:ClearFocus()
            refreshAll()
        end
    end
    add:SetScript("OnClick", doAdd)
    box:SetScript("OnEnterPressed", doAdd)
    box:SetScript("OnEscapePressed", box.ClearFocus)

    local rows = {}
    for i = 1, EXTRA_ROWS do
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(320, 20)
        row:SetPoint("TOPLEFT", x, y - 66 - (i - 1) * 22)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.text:SetPoint("LEFT", 4, 0)
        row.text:SetWidth(260)
        row.text:SetJustifyH("LEFT")
        row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.remove:SetSize(60, 18)
        row.remove:SetPoint("RIGHT")
        row.remove:SetText("Remove")
        row.remove:SetScript("OnClick", function()
            if row.id then
                ns.db.extra[row.id] = nil
                refreshAll()
            end
        end)
        rows[i] = row
    end
    local empty = label(parent, "Nothing added.", x + 4, y - 70, "GameFontDisable")

    refreshers[#refreshers + 1] = function()
        local ids = {}
        for id in pairs(ns.db.extra) do ids[#ids + 1] = id end
        table.sort(ids)
        for i, row in ipairs(rows) do
            local id = ids[i]
            row.id = id
            if id then
                row.text:SetText(("%s  |cff888888%d|r"):format(spellName(id), id))
                row:Show()
            else
                row:Hide()
            end
        end
        empty:SetShown(#ids == 0)
    end
end

-- Window -------------------------------------------------------------------------------

local function build()
    win = CreateFrame("Frame", "HeadsUpOptionsFrame", UIParent, "BackdropTemplate")
    win:SetSize(720, 470)
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
    title:SetText("Heads Up")
    local sub = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOP", title, "BOTTOM", 0, -2)
    sub:SetText("Spoken tank-buster warnings from BigWigs / LittleWigs")

    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    -- Left column: when and how it speaks.
    local L, R = 24, 380
    checkbox(win, "Enable callouts", "Speak tank busters during boss fights.", "enabled", L, -56)
    checkbox(win, "Only when I'm a tank", "Stay quiet unless your current specialization is a tank spec.", "onlyAsTank", L, -82)
    slider(win, "First callout (seconds before the hit)", "lead", 2, 10, 1, tostring, L, -118)
    slider(win, "Count down from  (0 = no countdown)", "countFrom", 0, 10, 1, tostring, L, -164)
    dropdown(win, "Wording", L, -210, function()
        return {
            { text = "Blade Combo, tank buster in 5", value = "both" },
            { text = "Blade Combo in 5",              value = "name" },
            { text = "Tank buster in 5",              value = "generic" },
        }
    end, function() return ns.db.phrasing end, function(v) ns.db.phrasing = v end)
    dropdown(win, "Voice", L, -262, voiceOptions,
        function() return ns.db.voiceID or false end,
        function(v) ns.db.voiceID = v or nil end)
    slider(win, "Speech speed", "rate", -10, 10, 1, tostring, L, -314)
    slider(win, "Volume", "volume", 0, 100, 5, tostring, L, -360)

    -- Right column: extra spells, preview, test.
    buildExtras(win, R, -56)

    label(win, "You'll hear", R, -318)
    local preview = label(win, "", R, -338, "GameFontHighlight")
    preview:SetWidth(320)
    preview:SetWordWrap(true)
    refreshers[#refreshers + 1] = function() preview:SetText(sampleLine()) end

    local test = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    test:SetSize(150, 26)
    test:SetPoint("TOPLEFT", R, -384)
    test:SetText("Test callout")
    test:SetScript("OnClick", function() ns.Watcher:Test() end)

    local hint = label(win, "/hu opens this window", R + 160, -390, "GameFontDisableSmall")
    hint:SetWidth(160)

    win:SetScript("OnShow", refreshAll)
end

function O:Open()
    if not win then build() end
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    win:Show()
    refreshAll()
end

function O:Toggle()
    if win and win:IsShown() then win:Hide() else self:Open() end
end

-- Options > AddOns > Heads Up: a short page with a button that opens the window.
function O:Init()
    local ok = pcall(function()
        local page = CreateFrame("Frame")
        page:SetSize(400, 200)
        local t = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        t:SetPoint("TOPLEFT", 16, -16)
        t:SetText("Heads Up")
        local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        b:SetSize(180, 26)
        b:SetPoint("TOPLEFT", 16, -48)
        b:SetText("Open Heads Up options")
        b:SetScript("OnClick", function() O:Open() end)
        local category = Settings.RegisterCanvasLayoutCategory(page, "Heads Up")
        Settings.RegisterAddOnCategory(category)
    end)
    if not ok then
        -- No Settings API: /hu still opens the window.
    end
end
