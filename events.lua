-------------------------------------------------------------------------------
-- events.lua — Central event hub
-- Registers WoW events in one place and routes them to the right module.
-- Everything starts on PLAYER_LOGIN, once SavedVariables are available.
-------------------------------------------------------------------------------
local _, NS = ...

NS.Events = {}

local eventFrame = CreateFrame("Frame")

function NS.Events:Register()
  eventFrame:RegisterEvent("PLAYER_LOGIN")

  eventFrame:SetScript("OnEvent", function(_, event, ...)
    NS.Events:OnEvent(event, ...)
  end)
end

-------------------------------------------------------------------------------
-- Router
-------------------------------------------------------------------------------

local handlers = {}

function NS.Events:OnEvent(event, ...)
  local fn = handlers[event]
  if fn then fn(self, ...) end
end

-------------------------------------------------------------------------------
-- PLAYER_LOGIN — one-time init
-------------------------------------------------------------------------------

handlers.PLAYER_LOGIN = function()
  eventFrame:UnregisterEvent("PLAYER_LOGIN")

  NS.Data:Initialize()
  NS.Options:RegisterBlizzardOptions()
  NS.Watcher:Initialize()

  -- Without LittleWigs there are no tank flags for dungeon bosses, so say so.
  if not NS.Utils:IsAddOnAvailable("LittleWigs") then
    NS.Utils:PrintWarning("LittleWigs isn't installed or is disabled, so dungeon tank busters won't be announced. Install LittleWigs to hear them.")
  end
end
