-------------------------------------------------------------------------------
-- watcher.lua — Tank-buster detection and the countdown driver
-- Sits on top of BigWigs/LittleWigs. BigWigs already works out which boss
-- ability each timer is (including from Blizzard's secret boss timeline), and
-- LittleWigs tags abilities as TANK / TANK_HEALER in each boss module. This
-- file listens to BigWigs' timer bars, keeps the tank ones, and speaks:
--   "<Ability>, tank buster in 5" ... "3" ... "2" ... "1"
-------------------------------------------------------------------------------
local _, NS = ...

NS.Watcher = {}

local math_floor = math.floor
local math_max   = math.max
local math_min   = math.min
local next       = next
local pairs      = pairs
local pcall      = pcall
local type       = type
local GetTime    = GetTime

local ET = C_EncounterTimeline
local bars   = {}  -- [module] = { [barText] = bar }
local recent = {}  -- [module] = { [key] = GetTime() of last callout }

local function Readable(v) return NS.Utils:Readable(v) end

--- Is this BigWigs option key a tank ability? CheckOption honours LittleWigs'
--- role flags (and returns nil for TANK options when you aren't a tank).
local function IsTankAbility(module, key)
  if NS.Data.db.extra[key] then return true end
  if type(module) ~= "table" or type(module.CheckOption) ~= "function" or key == nil then return false end
  local ok1, tank = pcall(module.CheckOption, module, key, "TANK")
  if ok1 and tank then return true end
  local ok2, both = pcall(module.CheckOption, module, key, "TANK_HEALER")
  return ok2 and both and true or false
end

--- Clean spoken name: the user's BigWigs rename, else the spell name, else
--- the bar text minus "(2)".
local function AbilityName(module, key, text)
  local ok, r = pcall(module.GetRename, module, key)
  if ok and type(r) == "string" and r ~= "" then return r end
  if type(module.SpellName) == "function" then
    local ok2, s = pcall(module.SpellName, module, key)
    if ok2 and type(s) == "string" and s ~= "" then return s end
  end
  text = Readable(text)
  if type(text) == "string" then return (text:gsub("%s*%(%d+%)%s*$", "")) end
  return nil
end

local function LiveRemaining(eventId)
  if not (eventId and ET and ET.GetEventTimeRemaining) then return nil end
  local ok, r = pcall(ET.GetEventTimeRemaining, eventId)
  r = ok and Readable(r)
  return type(r) == "number" and r or nil
end

local function ShouldSpeak(bar)
  if bar.isTest then return true end
  local db = NS.Data.db
  if not db.enabled then return false end
  if db.onlyAsTank and not NS.Utils:IsTankSpec() then return false end
  return true
end

-------------------------------------------------------------------------------
-- Timing
-------------------------------------------------------------------------------

--- If the countdown starts at or above the callout's own number, the callout
--- drops its number and moves earlier so it finishes before the first count.
function NS.Watcher:CountCoversCallout()
  return NS.Data:CountFrom() >= NS.Data.db.lead
end

--- Seconds before impact when the first callout plays.
function NS.Watcher:AnnounceAt()
  if self:CountCoversCallout() then return NS.Data:CountFrom() + NS.Config.COUNT_HEADROOM end
  return NS.Data.db.lead
end

-------------------------------------------------------------------------------
-- Countdown driver (only runs while there is something to count down)
-------------------------------------------------------------------------------

local ticker = CreateFrame("Frame")
local acc = 0
local OnTick -- defined below

local function Track(module, text, bar)
  bars[module] = bars[module] or {}
  bars[module][text] = bar
  ticker:SetScript("OnUpdate", OnTick)
end

local function Announce(bar)
  bar.announced = true
  if bar.module then
    recent[bar.module] = recent[bar.module] or {}
    recent[bar.module][bar.key] = GetTime()
  end
  local secs = math_max(0, math_floor(bar.remaining + 0.5))
  local countFrom = NS.Data:CountFrom()
  bar.speak = ShouldSpeak(bar)
  if NS.Watcher:CountCoversCallout() and bar.remaining > 0.5 then
    -- Countdown carries the numbers: "Blade Combo, tank buster ... 5, 4, 3, 2, 1"
    if bar.speak then NS.Speech:Announce(bar.name, nil) end
    bar.nextCount = math_min(countFrom, math_floor(bar.remaining - 0.5))
  else
    -- "Blade Combo, tank buster in 5 ... 3, 2, 1": only count numbers below
    -- the one just spoken, so they don't talk over it.
    if bar.speak then NS.Speech:Announce(bar.name, secs) end
    bar.nextCount = math_min(countFrom, secs - 1)
  end
end

OnTick = function(_, elapsed)
  acc = acc + elapsed
  if acc < NS.Config.TICK_INTERVAL then return end
  local dt = acc
  acc = 0
  if not next(bars) then
    ticker:SetScript("OnUpdate", nil)
    return
  end
  local lead = NS.Watcher:AnnounceAt()
  for module, list in pairs(bars) do
    for text, bar in pairs(list) do
      local live = LiveRemaining(bar.eventId)
      if live then
        bar.remaining = live
      elseif not bar.paused then
        bar.remaining = bar.remaining - dt
      end
      if not bar.paused then
        if not bar.announced and bar.remaining <= lead then
          if bar.remaining > -NS.Config.LATE_LIMIT then
            Announce(bar)
          else
            bar.announced, bar.nextCount = true, 0
          end
        elseif bar.announced and bar.speak and bar.nextCount >= 1 and bar.remaining <= bar.nextCount then
          NS.Speech:Count(bar.nextCount)
          bar.nextCount = bar.nextCount - 1
        end
      end
      if bar.remaining < -NS.Config.EXPIRE_AFTER then list[text] = nil end
    end
    if not next(list) then bars[module] = nil end
  end
  if not next(bars) then ticker:SetScript("OnUpdate", nil) end
end

-------------------------------------------------------------------------------
-- BigWigs messages
-------------------------------------------------------------------------------

--- BigWigs_StartBar: (event, module, key, text, time, icon, isApprox, maxTime, _, eventId)
function NS.Watcher:OnStartBar(_, module, key, text, time, _, _, _, _, eventId)
  if type(module) ~= "table" or text == nil then return end -- pull/break timers etc.
  text = Readable(text)
  if not text or not IsTankAbility(module, key) then return end
  time = Readable(type(time) == "table" and time[1] or time)
  if type(time) ~= "number" or time < NS.Config.MIN_BAR_SECONDS then return end

  -- Ignore a cast bar or restart for an ability we've just counted down.
  local last = recent[module] and recent[module][key]
  if last and GetTime() - last < self:AnnounceAt() + NS.Config.REPEAT_GRACE then return end

  Track(module, text, {
    module    = module,
    key       = key,
    name      = AbilityName(module, key, text),
    remaining = time,
    eventId   = Readable(eventId),
  })
end

function NS.Watcher:OnStopBar(_, module, text)
  if bars[module] then bars[module][text] = nil end
end

function NS.Watcher:OnPauseBar(_, module, text)
  local bar = bars[module] and bars[module][text]
  if bar then bar.paused = true end
end

function NS.Watcher:OnResumeBar(_, module, text)
  local bar = bars[module] and bars[module][text]
  if bar then bar.paused = false end
end

function NS.Watcher:OnModuleDone(_, module)
  bars[module] = nil
  recent[module] = nil
end

function NS.Watcher:Initialize()
  local loader = BigWigsLoader
  if not (loader and loader.RegisterMessage) then
    NS.Utils:PrintError("BigWigs isn't loaded, so there's nothing to listen to. Install BigWigs + LittleWigs.")
    return
  end
  local function On(msg, method)
    loader.RegisterMessage(NS.Watcher, msg, function(...) NS.Watcher[method](NS.Watcher, ...) end)
  end
  On("BigWigs_StartBar",      "OnStartBar")
  On("BigWigs_StopBar",       "OnStopBar")
  On("BigWigs_PauseBar",      "OnPauseBar")
  On("BigWigs_ResumeBar",     "OnResumeBar")
  On("BigWigs_StopBars",      "OnModuleDone")
  On("BigWigs_OnBossDisable", "OnModuleDone")
end

-------------------------------------------------------------------------------
-- /hu test — runs a fake tank buster through the same countdown path
-------------------------------------------------------------------------------

function NS.Watcher:Test(seconds)
  local at = self:AnnounceAt()
  seconds = math_max(at + 1, math_min(seconds or (at + 2), NS.Config.TEST_MAX))
  Track("test", "test", { isTest = true, key = "test", name = NS.Config.TEST_ABILITY, remaining = seconds })
  NS.Utils:PrintInfo(("Test: callout in %.0fs."):format(seconds - at))
end
