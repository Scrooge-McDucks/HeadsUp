-------------------------------------------------------------------------------
-- config.lua — Constants, defaults, and addon metadata
-- All tuning values live here. Nothing else should hard-code ranges, timings,
-- or sizes.
-------------------------------------------------------------------------------
local _, NS = ...

NS.Config = {}

-- Addon metadata
NS.Config.ADDON_NAME = NS.name or "HeadsUp"
NS.Config.TITLE      = "Heads Up"

-- Saved-variable defaults (HeadsUpDB, account-wide)
NS.Config.DEFAULTS = {
  enabled    = true,
  onlyAsTank = true,    -- stay quiet unless your current spec is a tank spec
  lead       = 5,       -- seconds before impact for the first callout
  countdown  = true,    -- false = first callout only, no numbers after it
  countFrom  = 3,       -- then count "3, 2, 1" (0 = no countdown)
  phrasing   = "both",  -- "both" | "name" | "generic"  (see speech.lua)
  sayTime    = true,    -- false = first callout leaves out "in 5"
  rate       = 3,       -- TTS speed, -10..10
  volume     = 100,     -- TTS volume, 0..100
  voiceID    = nil,     -- nil = your Blizzard TTS voice
  -- BigWigs option keys to treat as tank busters even though the boss module
  -- doesn't flag them TANK. Savage Maul (Dazar, King's Rest) stacks on the tank.
  extra      = { [1303488] = true },
}

-- Setting ranges (shared by the options window and slash commands)
NS.Config.LEAD_MIN   = 2
NS.Config.LEAD_MAX   = 10
NS.Config.COUNT_MIN  = 0
NS.Config.COUNT_MAX  = 10
NS.Config.RATE_MIN   = -10
NS.Config.RATE_MAX   = 10
NS.Config.VOLUME_MIN = 0
NS.Config.VOLUME_MAX = 100

-- Watcher timing (seconds)
NS.Config.TICK_INTERVAL   = 0.1  -- countdown driver runs at 10 Hz
NS.Config.MIN_BAR_SECONDS = 1    -- shorter bars are ignored
NS.Config.COUNT_HEADROOM  = 1.5  -- callout plays this early when the countdown carries the numbers
NS.Config.REPEAT_GRACE    = 4    -- after a callout, ignore restarts of that bar for callout time + this
NS.Config.LATE_LIMIT      = 0.5  -- a bar found this far past zero is dropped silently
NS.Config.EXPIRE_AFTER    = 2    -- forget a bar this long after it hits zero

-- /hu test
NS.Config.TEST_ABILITY = "Blade Combo"
NS.Config.TEST_MAX     = 30

-- Ability name used in the options preview
NS.Config.SAMPLE_ABILITY = "Blade Combo"

-- Options window
NS.Config.WINDOW = {
  width       = 720,
  height      = 530,
  leftX       = 24,
  rightX      = 380,
  columnWidth = 320,
  extraRows   = 8,
}

-- Chat message colours (hex, no leading |cff)
NS.Config.COLORS = {
  TAG  = "66ccff",  -- blue addon prefix
  INFO = "aaaaaa",  -- grey informational
  GOOD = "66ffcc",  -- teal success
  WARN = "ffcc66",  -- amber warning
  BAD  = "ff6666",  -- red error
}

-- Convenience accessor
function NS.Config:GetColor(name)
  return self.COLORS[name] or self.COLORS.INFO
end
