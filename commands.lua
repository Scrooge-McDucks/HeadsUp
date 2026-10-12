-------------------------------------------------------------------------------
-- commands.lua — Slash command registration and dispatch
-- All /hu subcommands are handled here, each delegating to the appropriate
-- module.
-------------------------------------------------------------------------------
local _, NS = ...

NS.Commands = {}

local math_floor    = math.floor
local string_format = string.format
local tonumber      = tonumber

function NS.Commands:Register()
  SLASH_HEADSUP1 = "/headsup"
  SLASH_HEADSUP2 = "/hu"

  SlashCmdList["HEADSUP"] = function(msg)
    NS.Commands:HandleCommand(msg)
  end
end

function NS.Commands:HandleCommand(msg)
  local cmd, rest = strsplit(" ", (msg or ""):lower(), 2)
  cmd = cmd or ""

  if cmd == "" or cmd == "options" or cmd == "config" then
    NS.Options:Toggle()
  elseif cmd == "help" then
    self:HandleHelp()
  elseif cmd == "test" then
    NS.Watcher:Test(tonumber(rest))
  elseif cmd == "lead" then
    self:HandleLead(rest)
  elseif cmd == "count" then
    self:HandleCount(rest)
  elseif cmd == "seconds" then
    self:HandleSeconds()
  elseif cmd == "add" then
    self:HandleAdd(rest)
  elseif cmd == "remove" then
    self:HandleRemove(rest)
  elseif cmd == "toggle" then
    self:HandleToggle()
  else
    NS.Utils:PrintError("Unknown command: " .. cmd)
    NS.Utils:PrintInfo("Type /hu help for available commands")
  end
end

-- Command handlers
function NS.Commands:HandleHelp()
  NS.Utils:PrintInfo("Available Commands:")
  NS.Utils:Print(nil, "  /hu - Open options window")
  NS.Utils:Print(nil, "  /hu test - Hear a full callout")
  NS.Utils:Print(nil, string_format("  /hu lead <secs> - First callout time (%d-%d)", NS.Config.LEAD_MIN, NS.Config.LEAD_MAX))
  NS.Utils:Print(nil, string_format("  /hu count <n> - Count down from n (%d-%d, 0 = off)", NS.Config.COUNT_MIN, NS.Config.COUNT_MAX))
  NS.Utils:Print(nil, "  /hu seconds - Say \"in 5\" in the first callout on/off")
  NS.Utils:Print(nil, "  /hu add <spellID> - Treat a spell as a tank buster")
  NS.Utils:Print(nil, "  /hu remove <spellID> - Remove a spell from that list")
  NS.Utils:Print(nil, "  /hu toggle - Enable/disable callouts")
  NS.Utils:Print(nil, "  /hu help - Show this help")
end

function NS.Commands:HandleLead(arg)
  local n = tonumber(arg)
  if not n then
    NS.Utils:PrintError("Usage: /hu lead <seconds>")
    return
  end
  local db = NS.Data.db
  db.lead = NS.Utils:Clamp(math_floor(n), NS.Config.LEAD_MIN, NS.Config.LEAD_MAX)
  NS.Utils:PrintSuccess(string_format("First callout %ds before impact.", db.lead))
end

function NS.Commands:HandleCount(arg)
  local n = tonumber(arg)
  if not n then
    NS.Utils:PrintError("Usage: /hu count <n>")
    return
  end
  local db = NS.Data.db
  db.countFrom = NS.Utils:Clamp(math_floor(n), NS.Config.COUNT_MIN, NS.Config.COUNT_MAX)
  db.countdown = true
  if db.countFrom == 0 then
    NS.Utils:PrintSuccess("Countdown off.")
  else
    NS.Utils:PrintSuccess(string_format("Countdown from %d.", db.countFrom))
  end
end

function NS.Commands:HandleSeconds()
  local db = NS.Data.db
  db.sayTime = not db.sayTime
  NS.Utils:PrintSuccess(db.sayTime and "Callout says the seconds." or "Callout leaves out the seconds.")
end

function NS.Commands:HandleAdd(arg)
  local id = tonumber(arg)
  if not id then
    NS.Utils:PrintError("Usage: /hu add <spellID>")
    return
  end
  NS.Data.db.extra[id] = true
  NS.Utils:PrintSuccess("Spell " .. id .. " will be treated as a tank buster.")
end

function NS.Commands:HandleRemove(arg)
  local id = tonumber(arg)
  if not id then
    NS.Utils:PrintError("Usage: /hu remove <spellID>")
    return
  end
  NS.Data.db.extra[id] = nil
  NS.Utils:PrintSuccess("Spell " .. id .. " removed from the extra list.")
end

function NS.Commands:HandleToggle()
  local db = NS.Data.db
  db.enabled = not db.enabled
  NS.Utils:PrintSuccess(db.enabled and "Enabled." or "Disabled.")
end
