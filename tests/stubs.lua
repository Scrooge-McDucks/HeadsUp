-- Minimal World of Warcraft API stubs for offline unit tests.
-- Plain Lua 5.1 compatible. Each call to load() gives a fresh addon state.

local M = {}

-- A value the stubbed client treats as secret (Midnight).
function M.secret(v)
    return { __secret = true, value = v }
end

local function newCtx(opts)
    local ctx = {
        frames   = {},          -- every frame/widget created, in order
        spoken   = {},          -- { id, msg, t } for each SpeakText call
        printed  = {},          -- every line printed by the addon
        clock    = 0,           -- fake GetTime()
        handlers = {},          -- BigWigs message handlers by message name
        tank     = opts.tank ~= false,
        lwLoaded = opts.lwLoaded ~= false,
        speakError = opts.speakError,
        voices   = opts.voices or {
            { voiceID = 0, name = "Microsoft David" },
            { voiceID = 1, name = "Microsoft Zira" },
        },
        loadingFile = nil,
    }

    local Widget = {}
    local mt = {}
    mt.__index = function(_, k)
        return Widget[k] or function() end -- any unstubbed widget method is a no-op
    end

    local function newWidget(kind, name)
        local o = {
            kind = kind, name = name, file = ctx.loadingFile,
            scripts = {}, events = {}, shown = true,
            value = 0, checked = false, text = "",
        }
        return setmetatable(o, mt)
    end

    function Widget.SetScript(self, k, fn) self.scripts[k] = fn end
    Widget.HookScript = Widget.SetScript
    function Widget.GetScript(self, k) return self.scripts[k] end
    function Widget.RegisterEvent(self, e) self.events[e] = true end
    function Widget.UnregisterEvent(self, e) self.events[e] = nil end
    function Widget.RegisterForDrag() end
    function Widget.SetValue(self, v)
        self.value = v
        if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end
    end
    function Widget.GetValue(self) return self.value end
    function Widget.SetChecked(self, v) self.checked = v end
    function Widget.GetChecked(self) return self.checked end
    function Widget.SetText(self, t) self.text = t end
    function Widget.GetText(self) return self.text end
    function Widget.Show(self)
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function Widget.Hide(self) self.shown = false end
    function Widget.IsShown(self) return self.shown end
    function Widget.SetShown(self, v) self.shown = v and true or false end
    function Widget.SetupMenu(self, fn) self.menuFn = fn end
    function Widget.CreateFontString()
        return ctx.make("FontString")
    end
    function Widget.CreateTexture()
        return ctx.make("Texture")
    end

    function ctx.make(kind, name)
        local o = newWidget(kind, name)
        ctx.frames[#ctx.frames + 1] = o
        return o
    end

    -- Globals -----------------------------------------------------------------
    _G.CreateFrame = function(kind, name, parent, template)
        local o = ctx.make(kind, name)
        if name then _G[name] = o end
        return o
    end
    _G.UIParent = newWidget("UIParent")
    _G.GameTooltip = newWidget("GameTooltip")
    _G.GameTooltip_Hide = function() end
    _G.HideUIPanel = function() end
    _G.UISpecialFrames = {}
    _G.HeadsUpOptionsFrame = nil
    _G.SettingsPanel = nil

    _G.GetTime = function() return ctx.clock end
    _G.print = function(...)
        local t = {}
        for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
        ctx.printed[#ctx.printed + 1] = table.concat(t, " ")
    end
    _G.strsplit = function(_, s)
        local a, b = s:match("^(%S*)%s*(.-)$")
        return a, (b ~= "" and b or nil)
    end
    _G.CopyTable = function(t)
        local r = {}
        for k, v in pairs(t) do r[k] = v end
        return r
    end
    _G.tinsert = function(t, v) t[#t + 1] = v end
    _G.GetSpecialization = function() return 1 end
    _G.GetSpecializationRole = function() return ctx.tank and "TANK" or "DAMAGER" end
    _G.issecretvalue = function(v) return type(v) == "table" and v.__secret == true end

    _G.C_VoiceChat = {
        SpeakText = function(id, msg)
            if ctx.speakError then error("tts boom") end
            ctx.spoken[#ctx.spoken + 1] = { id = id, msg = msg, t = ctx.clock }
        end,
        GetTtsVoices = function()
            local copy = {}
            for i, v in ipairs(ctx.voices) do copy[i] = { voiceID = v.voiceID, name = v.name } end
            return copy
        end,
    }
    _G.C_TTSSettings = { GetVoiceOptionID = function() return 0 end }
    _G.Enum = { TtsVoiceType = { Standard = 0 } }
    _G.C_Spell = {
        GetSpellName = function(id)
            return ({ [1303488] = "Savage Maul", [270487] = "Severing Blade" })[id]
        end,
    }
    _G.C_AddOns = {
        IsAddOnLoaded = function(name) return name == "LittleWigs" and ctx.lwLoaded end,
    }
    _G.C_EncounterTimeline = nil -- no live timeline: Watcher counts down from BigWigs' time
    _G.SlashCmdList = {}
    _G.Settings = {
        RegisterCanvasLayoutCategory = function(_, name) return { name = name } end,
        RegisterAddOnCategory = function() end,
    }
    _G.BigWigsLoader = {
        RegisterMessage = function(_, msg, fn) ctx.handlers[msg] = fn end,
    }

    -- Test helpers ------------------------------------------------------------
    -- Fire a BigWigs message the way the loader does (message name first).
    function ctx.emit(msg, ...)
        local fn = ctx.handlers[msg]
        if fn then fn(msg, ...) end
    end

    -- Fire a game event on every frame that registered for it.
    function ctx.fire(event, ...)
        for _, f in ipairs(ctx.frames) do
            if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
        end
    end

    -- Advance the fake clock and run the countdown ticker in 0.1s steps.
    function ctx.advance(seconds)
        local steps = math.floor(seconds * 10 + 0.5)
        for _ = 1, steps do
            ctx.clock = ctx.clock + 0.1
            local fn = ctx.ticker and ctx.ticker.scripts.OnUpdate
            if fn then fn(ctx.ticker, 0.1) end
        end
    end

    function ctx.spokenMessages()
        local out = {}
        for i, s in ipairs(ctx.spoken) do out[i] = s.msg end
        return out
    end

    function ctx.countPrinted(needle)
        local n = 0
        for _, line in ipairs(ctx.printed) do
            if line:find(needle, 1, true) then n = n + 1 end
        end
        return n
    end

    return ctx
end

-- A boss module as BigWigs exposes it: flags maps option key -> "TANK" | "TANK_HEALER".
function M.module(flags, names)
    return {
        flags = flags or {},
        names = names or {},
        CheckOption = function(self, key, flag) return self.flags[key] == flag end,
        GetRename = function() return nil end,
        SpellName = function(self, key) return self.names[key] end,
    }
end

-- Load Core, Speech, Watcher and Options from `root`, fire ADDON_LOADED, and
-- return the context. opts: db (saved variables), tank, lwLoaded, voices, speakError.
function M.load(root, opts)
    opts = opts or {}
    local ctx = newCtx(opts)
    _G.HeadsUpDB = opts.db
    local ns = {}
    for _, file in ipairs({ "Core", "Speech", "Watcher", "Options" }) do
        ctx.loadingFile = file .. ".lua"
        local chunk, err = loadfile(root .. "/Sources/" .. file .. ".lua")
        assert(chunk, err)
        chunk("HeadsUp", ns)
    end
    ctx.loadingFile = nil
    ctx.ns = ns
    ctx.fire("ADDON_LOADED", "HeadsUp")
    for _, f in ipairs(ctx.frames) do
        if f.file == "Watcher.lua" and f.kind == "Frame" then ctx.ticker = f break end
    end
    ctx.db = ns.db
    return ctx
end

return M
