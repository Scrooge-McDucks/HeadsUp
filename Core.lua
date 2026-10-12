-- Heads Up: Core
-- Namespace, saved variables and slash commands.

local ADDON, ns = ...
ns.name = ADDON

-- issecretvalue only exists on 12.x clients; treat everything as readable elsewhere.
ns.IsSecret = issecretvalue or function() return false end

-- Where the countdown starts; 0 when it's switched off.
function ns.CountFrom()
    return ns.db.countdown and ns.db.countFrom or 0
end

-- Returns v only when it is a plain, readable value.
function ns.Readable(v)
    if v ~= nil and not ns.IsSecret(v) then return v end
    return nil
end

ns.defaults = {
    enabled    = true,
    onlyAsTank = true,   -- stay quiet unless your current spec is a tank spec
    lead       = 5,      -- seconds before impact for the first callout
    countdown  = true,   -- false = first callout only, no numbers after it
    countFrom  = 3,      -- then count "3, 2, 1" (0 = no countdown)
    phrasing   = "both", -- "both" | "name" | "generic"  (see Speech.lua)
    sayTime    = true,   -- false = first callout leaves out "in 5"
    rate       = 3,      -- TTS speed, -10..10
    volume     = 100,    -- TTS volume, 0..100
    voiceID    = nil,    -- nil = your Blizzard TTS voice
    -- BigWigs option keys to treat as tank busters even though the boss module
    -- doesn't flag them TANK. Savage Maul (Dazar, King's Rest) stacks on the tank.
    extra      = { [1303488] = true },
}

local function applyDefaults(db, defaults)
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = (type(v) == "table") and CopyTable(v) or v
        end
    end
end

function ns.Print(msg)
    print("|cff66ccffHeads Up|r: " .. msg)
end

function ns.IsTankSpec()
    local spec = GetSpecialization and GetSpecialization()
    if not spec then return false end
    return GetSpecializationRole(spec) == "TANK"
end

local function isLoaded(addon)
    local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return fn and fn(addon) and true or false
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" then
        -- Without LittleWigs there are no tank flags for dungeon bosses, so say so.
        if not isLoaded("LittleWigs") then
            ns.Print("LittleWigs isn't loaded, so dungeon tank busters won't be announced. Install LittleWigs to hear them.")
        end
        f:UnregisterEvent("PLAYER_LOGIN")
        return
    end
    if name ~= ADDON then return end
    HeadsUpDB = HeadsUpDB or {}
    applyDefaults(HeadsUpDB, ns.defaults)
    ns.db = HeadsUpDB
    ns.Config:Init()
    ns.Watcher:Init()
    f:UnregisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_LOGIN")
end)

-- Addon compartment (minimap drawer) entry, named in the TOC.
function HeadsUp_OnCompartmentClick()
    ns.Config:Toggle()
end

SLASH_HEADSUP1 = "/headsup"
SLASH_HEADSUP2 = "/hu"
SlashCmdList.HEADSUP = function(input)
    local cmd, rest = strsplit(" ", (input or ""):lower(), 2)
    if cmd == "test" then
        ns.Watcher:Test(tonumber(rest))
    elseif cmd == "lead" and tonumber(rest) then
        ns.db.lead = math.max(2, math.min(10, math.floor(tonumber(rest))))
        ns.Print(("First callout %ds before impact."):format(ns.db.lead))
    elseif cmd == "count" and tonumber(rest) then
        ns.db.countFrom = math.max(0, math.min(10, math.floor(tonumber(rest))))
        ns.db.countdown = true
        ns.Print(ns.db.countFrom == 0 and "Countdown off." or ("Countdown from %d."):format(ns.db.countFrom))
    elseif cmd == "seconds" then
        ns.db.sayTime = not ns.db.sayTime
        ns.Print(ns.db.sayTime and "Callout says the seconds." or "Callout leaves out the seconds.")
    elseif cmd == "add" then
        if tonumber(rest) then
            ns.db.extra[tonumber(rest)] = true
            ns.Print("Spell " .. rest .. " will be treated as a tank buster.")
        else
            ns.Print("Usage: /hu add <spellID>")
        end
    elseif cmd == "remove" then
        if tonumber(rest) then
            ns.db.extra[tonumber(rest)] = nil
            ns.Print("Spell " .. rest .. " removed from the extra list.")
        else
            ns.Print("Usage: /hu remove <spellID>")
        end
    elseif cmd == "toggle" then
        ns.db.enabled = not ns.db.enabled
        ns.Print(ns.db.enabled and "Enabled." or "Disabled.")
    elseif cmd == "help" then
        ns.Print("/hu - options window | /hu test - hear a full callout | /hu lead <secs> | /hu count <n> | /hu seconds | /hu add <spellID> | /hu remove <spellID> | /hu toggle")
    else
        ns.Config:Toggle()
    end
end
