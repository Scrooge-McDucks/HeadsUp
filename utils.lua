-------------------------------------------------------------------------------
-- utils.lua — Shared helpers: chat output, secret values, spec and addon checks
-------------------------------------------------------------------------------
local _, NS = ...

NS.Utils = {}

local math_max = math.max
local math_min = math.min
local tostring = tostring

-------------------------------------------------------------------------------
-- Chat output
-------------------------------------------------------------------------------
local function ColorText(hex, text)
  return "|cff" .. hex .. tostring(text) .. "|r"
end

local function GetAddonTag()
  return ColorText(NS.Config:GetColor("TAG"), NS.Config.TITLE .. ":") .. " "
end

function NS.Utils:Print(hex, text)
  if hex then
    print(GetAddonTag() .. ColorText(hex, text))
  else
    print(GetAddonTag() .. tostring(text))
  end
end

function NS.Utils:PrintInfo(text)    self:Print(NS.Config:GetColor("INFO"), text) end
function NS.Utils:PrintSuccess(text) self:Print(NS.Config:GetColor("GOOD"), text) end
function NS.Utils:PrintWarning(text) self:Print(NS.Config:GetColor("WARN"), text) end
function NS.Utils:PrintError(text)   self:Print(NS.Config:GetColor("BAD"),  text) end

-------------------------------------------------------------------------------
-- Secret values (Midnight)
-------------------------------------------------------------------------------

-- issecretvalue only exists on 12.x clients; treat everything as readable elsewhere.
local IsSecret = issecretvalue or function() return false end

--- Returns v only when it is a plain, readable value.
function NS.Utils:Readable(v)
  if v ~= nil and not IsSecret(v) then return v end
  return nil
end

-------------------------------------------------------------------------------
-- Game state
-------------------------------------------------------------------------------

function NS.Utils:IsTankSpec()
  local spec = GetSpecialization and GetSpecialization()
  if not spec then return false end
  return GetSpecializationRole(spec) == "TANK"
end

--- True when the addon is loaded, or installed and enabled so it can still
--- load later (LittleWigs is load-on-demand: BigWigs loads it in dungeons).
function NS.Utils:IsAddOnAvailable(name)
  local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
  if isLoaded and isLoaded(name) then return true end
  local getInfo = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
  if not getInfo then return false end
  local ok, _, _, _, loadable = pcall(getInfo, name)
  return ok and loadable and true or false
end

-------------------------------------------------------------------------------
-- Math
-------------------------------------------------------------------------------

function NS.Utils:Clamp(v, lo, hi)
  return math_max(lo, math_min(hi, v))
end
