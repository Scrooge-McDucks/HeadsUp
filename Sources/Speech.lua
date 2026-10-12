-- Heads Up: Speech (voice only)

local _, ns = ...
local S = {}
ns.Speech = S

local function voiceID()
    if ns.db.voiceID then return ns.db.voiceID end
    if C_TTSSettings and C_TTSSettings.GetVoiceOptionID and Enum.TtsVoiceType then
        local ok, id = pcall(C_TTSSettings.GetVoiceOptionID, Enum.TtsVoiceType.Standard)
        if ok and id then return id end
    end
    local voices = C_VoiceChat.GetTtsVoices and C_VoiceChat.GetTtsVoices()
    return voices and voices[1] and voices[1].voiceID or 0
end

function S:Say(msg)
    pcall(C_VoiceChat.SpeakText, voiceID(), msg, ns.db.rate, ns.db.volume, true)
end

-- First callout:
--   both    -> "Blade Combo, tank buster in 5"
--   name    -> "Blade Combo in 5"
--   generic -> "Tank buster in 5"
-- seconds = nil drops the number (the countdown that follows supplies it).
function S:Announce(name, seconds)
    local mode = ns.db.phrasing
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
        msg = ("%s, tank buster in %d"):format(name, seconds)
    elseif name then
        msg = ("%s in %d"):format(name, seconds)
    else
        msg = ("Tank buster in %d"):format(seconds)
    end
    self:Say(msg)
end

function S:Count(n)
    self:Say(tostring(n))
end
