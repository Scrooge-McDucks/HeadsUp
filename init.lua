-------------------------------------------------------------------------------
-- init.lua — Bootstrap (loaded last in the TOC)
-- Registers slash commands, hooks up the event frame, and exposes the
-- global handlers required by the Blizzard Addon Compartment API.
-- Everything else happens on PLAYER_LOGIN inside events.lua.
-------------------------------------------------------------------------------
local ADDON_NAME, NS = ...
NS.name = ADDON_NAME

if NS.Commands then NS.Commands:Register() end
if NS.Events   then NS.Events:Register()   end

-------------------------------------------------------------------------------
-- Addon Compartment handlers (must be global — looked up by name in _G)
-- These let the addon appear in the minimap addon list (11.0+).
-------------------------------------------------------------------------------

function HeadsUp_OnAddonCompartmentClick()
  if NS.Options then NS.Options:Toggle() end
end

function HeadsUp_OnAddonCompartmentEnter(addonFrame)
  GameTooltip:SetOwner(addonFrame, "ANCHOR_NONE")
  GameTooltip:SetPoint("TOPRIGHT", addonFrame, "BOTTOMRIGHT", 0, 0)
  GameTooltip:AddLine(NS.Config.TITLE)
  GameTooltip:AddLine("Click: Options", 1, 1, 1)
  if NS.Data and NS.Data.db and not NS.Data.db.enabled then
    GameTooltip:AddLine("Callouts are off", 1, 0.4, 0.4)
  end
  GameTooltip:Show()
end

function HeadsUp_OnAddonCompartmentLeave()
  GameTooltip:Hide()
end
