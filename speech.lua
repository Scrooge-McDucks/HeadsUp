-------------------------------------------------------------------------------
-- speech.lua — Text-to-speech output
-- Builds the spoken lines and sends them through Blizzard TTS with the chosen
-- voice, speed and volume.
-------------------------------------------------------------------------------
local _, NS = ...

NS.Speech = {}
NS.Speech.warnedMissingVoice = false
NS.Speech.warnedSpeakError   = false

local ipairs        = ipairs
local pcall         = pcall
local tostring      = tostring
local string_format = string.format

-- Voice IDs belong to the voices installed on this computer, and HeadsUpDB is
-- account-wide, so a saved voice may not exist here. Fall back to the default.
local function InstalledVoices()
  return (C_VoiceChat.GetTtsVoices and C_VoiceChat.GetTtsVoices()) or {}
end

local function VoiceID()
  local saved = NS.Data.db.voiceID
  if saved then
    local voices = InstalledVoices()
    if #voices == 0 then return saved end -- list not ready yet: trust the saved ID
    for _, v in ipairs(voices) do
      if v.voiceID == saved then return saved end
    end
    if not NS.Speech.warnedMissingVoice then
      NS.Speech.warnedMissingVoice = true
      NS.Utils:PrintWarning("Your saved voice isn't installed on this computer, so the default voice is used. Pick another in /hu.")
    end
  end
  if C_TTSSettings and C_TTSSettings.GetVoiceOptionID and Enum.TtsVoiceType then
    local ok, id = pcall(C_TTSSettings.GetVoiceOptionID, Enum.TtsVoiceType.Standard)
    if ok and id then return id end
  end
  local voices = InstalledVoices()
  return voices[1] and voices[1].voiceID or 0
end

function NS.Speech:Say(msg)
  local db = NS.Data.db
  local ok, err = pcall(C_VoiceChat.SpeakText, VoiceID(), msg, db.rate, db.volume, true)
  if not ok and not self.warnedSpeakError then
    self.warnedSpeakError = true
    NS.Utils:PrintError("Couldn't speak through text-to-speech: " .. tostring(err))
  end
end

--- First callout:
---   both    -> "Blade Combo, tank buster in 5"
---   name    -> "Blade Combo in 5"
---   generic -> "Tank buster in 5"
--- seconds = nil drops the number (the countdown that follows supplies it, or
--- "Say the seconds" is off). A late callout still says "now".
function NS.Speech:Announce(name, seconds)
  local db = NS.Data.db
  local mode = db.phrasing
  if not db.sayTime and seconds and seconds > 0 then seconds = nil end
  if mode == "generic" or not name then name = nil end
  local msg
  if seconds == nil then
    if mode == "both" and name then
      msg = name .. ", tank buster"
    else
      msg = name or "Tank buster"
    end
  elseif seconds <= 0 then
    msg = name and (name .. " now") or "Tank buster now"
  elseif mode == "both" and name then
    msg = string_format("%s, tank buster in %d", name, seconds)
  elseif name then
    msg = string_format("%s in %d", name, seconds)
  else
    msg = string_format("Tank buster in %d", seconds)
  end
  self:Say(msg)
end

function NS.Speech:Count(n)
  self:Say(tostring(n))
end
