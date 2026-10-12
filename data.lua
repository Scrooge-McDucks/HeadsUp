-------------------------------------------------------------------------------
-- data.lua — SavedVariables (HeadsUpDB) and derived settings
-------------------------------------------------------------------------------
local _, NS = ...

NS.Data = {}
NS.Data.db = nil

local pairs = pairs
local type  = type

local function ApplyDefaults(db, defaults)
  for k, v in pairs(defaults) do
    if db[k] == nil then
      db[k] = (type(v) == "table") and CopyTable(v) or v
    end
  end
end

function NS.Data:Initialize()
  HeadsUpDB = HeadsUpDB or {}
  ApplyDefaults(HeadsUpDB, NS.Config.DEFAULTS)
  self.db = HeadsUpDB
end

--- Where the countdown starts; 0 when it's switched off.
function NS.Data:CountFrom()
  return self.db.countdown and self.db.countFrom or 0
end
