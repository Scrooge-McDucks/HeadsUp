-- Heads Up: Watcher
-- Sits on top of BigWigs/LittleWigs. BigWigs already works out which boss
-- ability each timer is (including from Blizzard's secret boss timeline), and
-- LittleWigs tags abilities as TANK / TANK_HEALER in each boss module. This
-- file listens to BigWigs' timer bars, keeps the tank ones, and speaks:
--   "<Ability>, tank buster in 5" ... "3" ... "2" ... "1"

local _, ns = ...
local W = {}
ns.Watcher = W

local ET = C_EncounterTimeline
local bars = {}   -- [module] = { [barText] = bar }
local recent = {} -- [module] = { [key] = GetTime() of last callout }

local function readable(v) return ns.Readable(v) end

-- Is this BigWigs option key a tank ability? CheckOption honours LittleWigs'
-- role flags (and returns nil for TANK options when you aren't a tank).
local function isTankAbility(module, key)
    if ns.db.extra[key] then return true end
    if type(module) ~= "table" or type(module.CheckOption) ~= "function" or key == nil then return false end
    local ok1, tank = pcall(module.CheckOption, module, key, "TANK")
    if ok1 and tank then return true end
    local ok2, both = pcall(module.CheckOption, module, key, "TANK_HEALER")
    return ok2 and both and true or false
end

-- Clean spoken name: the user's BigWigs rename, else the spell name, else the bar text minus "(2)".
local function abilityName(module, key, text)
    local ok, r = pcall(module.GetRename, module, key)
    if ok and type(r) == "string" and r ~= "" then return r end
    if type(module.SpellName) == "function" then
        local ok2, s = pcall(module.SpellName, module, key)
        if ok2 and type(s) == "string" and s ~= "" then return s end
    end
    text = readable(text)
    if type(text) == "string" then return (text:gsub("%s*%(%d+%)%s*$", "")) end
    return nil
end

local function liveRemaining(eventId)
    if not (eventId and ET and ET.GetEventTimeRemaining) then return nil end
    local ok, r = pcall(ET.GetEventTimeRemaining, eventId)
    r = ok and readable(r)
    return type(r) == "number" and r or nil
end

local function shouldSpeak(bar)
    if bar.isTest then return true end
    if not ns.db.enabled then return false end
    if ns.db.onlyAsTank and not ns.IsTankSpec() then return false end
    return true
end

local function track(module, text, bar)
    bars[module] = bars[module] or {}
    bars[module][text] = bar
end

-- BigWigs_StartBar: (event, module, key, text, time, icon, isApprox, maxTime, _, eventId)
function W:OnStartBar(_, module, key, text, time, _, _, _, _, eventId)
    if type(module) ~= "table" or text == nil then return end -- pull/break timers etc.
    text = readable(text)
    if not text or not isTankAbility(module, key) then return end
    time = readable(type(time) == "table" and time[1] or time)
    if type(time) ~= "number" or time < 1 then return end

    -- Ignore a cast bar or restart for an ability we've just counted down.
    local last = recent[module] and recent[module][key]
    if last and GetTime() - last < ns.db.lead + 4 then return end

    track(module, text, {
        module    = module,
        key       = key,
        name      = abilityName(module, key, text),
        remaining = time,
        eventId   = readable(eventId),
    })
end

function W:OnStopBar(_, module, text)
    if bars[module] then bars[module][text] = nil end
end

function W:OnPauseBar(_, module, text)
    local bar = bars[module] and bars[module][text]
    if bar then bar.paused = true end
end

function W:OnResumeBar(_, module, text)
    local bar = bars[module] and bars[module][text]
    if bar then bar.paused = false end
end

function W:OnModuleDone(_, module)
    bars[module] = nil
    recent[module] = nil
end

local function announce(bar)
    bar.announced = true
    if bar.module then
        recent[bar.module] = recent[bar.module] or {}
        recent[bar.module][bar.key] = GetTime()
    end
    local secs = math.max(0, math.floor(bar.remaining + 0.5))
    bar.speak = shouldSpeak(bar)
    if W.CountCoversCallout() and bar.remaining > 0.5 then
        -- Countdown carries the numbers: "Blade Combo, tank buster ... 5, 4, 3, 2, 1"
        if bar.speak then ns.Speech:Announce(bar.name, nil) end
        bar.nextCount = math.min(ns.db.countFrom, math.floor(bar.remaining - 0.5))
    else
        -- "Blade Combo, tank buster in 5 ... 3, 2, 1": only count numbers below
        -- the one just spoken, so they don't talk over it.
        if bar.speak then ns.Speech:Announce(bar.name, secs) end
        bar.nextCount = math.min(ns.db.countFrom, secs - 1)
    end
end

-- If the countdown starts at or above the callout's own number, the callout
-- drops its number and moves 1.5s earlier so it finishes before "5" is said.
function W.CountCoversCallout()
    return ns.db.countFrom >= ns.db.lead
end

function W.AnnounceAt()
    if W.CountCoversCallout() then return ns.db.countFrom + 1.5 end
    return ns.db.lead
end

-- 10 Hz countdown driver.
local ticker = CreateFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.1 then return end
    local dt = acc
    acc = 0
    if not next(bars) then return end
    local lead = W.AnnounceAt()
    for module, list in pairs(bars) do
        for text, bar in pairs(list) do
            local live = liveRemaining(bar.eventId)
            if live then
                bar.remaining = live
            elseif not bar.paused then
                bar.remaining = bar.remaining - dt
            end
            if not bar.paused then
                if not bar.announced and bar.remaining <= lead then
                    if bar.remaining > -0.5 then announce(bar) else bar.announced, bar.nextCount = true, 0 end
                elseif bar.announced and bar.speak and bar.nextCount >= 1 and bar.remaining <= bar.nextCount then
                    ns.Speech:Count(bar.nextCount)
                    bar.nextCount = bar.nextCount - 1
                end
            end
            if bar.remaining < -2 then list[text] = nil end
        end
        if not next(list) then bars[module] = nil end
    end
end)

function W:Init()
    local loader = BigWigsLoader
    if not (loader and loader.RegisterMessage) then
        ns.Print("BigWigs isn't loaded, so there's nothing to listen to. Install BigWigs + LittleWigs.")
        return
    end
    local function on(msg, method)
        loader.RegisterMessage(W, msg, function(...) W[method](W, ...) end)
    end
    on("BigWigs_StartBar", "OnStartBar")
    on("BigWigs_StopBar", "OnStopBar")
    on("BigWigs_PauseBar", "OnPauseBar")
    on("BigWigs_ResumeBar", "OnResumeBar")
    on("BigWigs_StopBars", "OnModuleDone")
    on("BigWigs_OnBossDisable", "OnModuleDone")
end

-- /hu test: runs a fake tank buster through the same countdown path.
function W:Test(seconds)
    local at = W.AnnounceAt()
    seconds = math.max(at + 1, math.min(seconds or (at + 2), 30))
    track("test", "test", { isTest = true, key = "test", name = "Blade Combo", remaining = seconds })
    ns.Print(("Test: callout in %.0fs."):format(seconds - at))
end
