-- A simulated client: the parts of the game, Chattynator and LibSpecialization the addon touches.
-- NewClient() resets the globals, loads the .toc's own files and logs in.
--
-- A tree's icon is classID * 100 + tree index (a Paladin's are 201, 202, 203). On Forever a spec's
-- icon is its spec ID + 5000.

---@class TestMember
---@field unit string "party1", "raid3"
---@field name string "Name-Realm"
---@field classID number
---@field trees number[] points per tree, what an inspect shows
---@field inRange boolean? default true
---@field canInspect boolean? default true

---@class TestClientOptions
---@field client "era"|"forever"? default "era"
---@field trees number[]? the player's points per tree, default { 0, 5, 31 }
---@field guild boolean? in a guild, default true
---@field group TestMember[]? default none
---@field raid boolean? the group is a raid
---@field specId number? Forever: the player's spec, default 70
---@field debugLog boolean? _DebugLog is loaded
---@field tacoTip boolean? TacoTip's LibClassicInspector is loaded (Classic Era)
---@field eltruism boolean? Eltruism (ElvUI_EltreumUI) is loaded
---@field fontSize number? Chattynator's message font size in its current profile; none: no profile yet

local PLAYER = "Me-Realm"
local PLAYER_CLASS = 2

---@param options TestClientOptions?
function NewClient(options)
    options = options or {}
    local client = {
        trees = options.trees or { 0, 5, 31 },
        guild = options.guild ~= false,
        group = options.group or {},
        raid = options.raid or false,
        specId = options.specId or 70,
        combat = false,
        time = 0,
        events = {},
        modifiers = {},
        sent = {},
        timers = {},
        inspects = {},
        cleared = 0,
        guildRequests = 0,
        logged = {},
    }

    ---@param event string
    function client:Fire(event, ...)
        for _, callback in ipairs(self.events[event] or {}) do
            callback("owner", ...)
        end
    end

    ---The text Chattynator shows for a line from name, after the modifiers.
    ---@param name string "Name-Realm"
    ---@return string
    function client:Chat(name)
        local short = name:match("^[^-]+")
        local data = {
            text = ("|Hplayer:%s:1:GUILD|h[%s]|h: hello"):format(name, short),
            typeInfo = { player = { name = name } },
        }
        for _, modifier in ipairs(self.modifiers) do
            modifier(data)
        end
        return data.text
    end

    ---The icon markup shown for name, or nil.
    ---@param name string
    ---@return string?
    function client:Icon(name)
        return self:Chat(name):match("^|Hplayer:[^|]+|h%[(|T[^|]+|t)")
    end

    ---An addon message arriving from sender.
    function client:Receive(sender, text, channel, prefix)
        self:Fire("CHAT_MSG_ADDON", prefix or self.prefix, text, channel or "GUILD", sender)
    end

    ---The addon messages sent, as "CHANNEL text", and forgets them.
    ---@return string[]
    function client:TakeSent()
        local sent = self.sent
        self.sent = {}
        return sent
    end

    function client:RunTimers()
        local timers = self.timers
        self.timers = {}
        for _, timer in ipairs(timers) do
            timer()
        end
    end

    ---Lets seconds pass, calling the ticker for each interval in them.
    function client:Wait(seconds)
        local stop = self.time + seconds
        while self.ticker and self.time + self.ticker.interval <= stop do
            self.time = self.time + self.ticker.interval
            self.ticker.fn()
        end
        self.time = stop
    end

    ---The client answers the last inspect, for the member it was sent to or for guid.
    function client:InspectReady(guid)
        local unit = guid or self.inspects[#self.inspects]
        for _, member in ipairs(self.group) do
            if member.unit == unit then self.inspected = member end
        end
        self:Fire("INSPECT_READY", "guid-" .. unit)
    end

    local function member(unit)
        for _, m in ipairs(client.group) do
            if m.unit == unit then return m end
        end
    end

    -- Game API
    _G.EventRegistry = {
        RegisterFrameEventAndCallback = function(_, event, callback)
            client.events[event] = client.events[event] or {}
            table.insert(client.events[event], callback)
        end,
    }
    _G.Chattynator = {
        API = {
            AddModifier = function(modifier)
                table.insert(client.modifiers, modifier)
            end,
        },
    }
    _G.DLAPI = options.debugLog
            and {
                DebugLog = function(_, text)
                    table.insert(client.logged, text)
                end,
            }
        or nil
    _G.format = string.format
    _G.gsub = string.gsub
    _G.CreateSimpleTextureMarkup = function(file, width, height)
        return ("|T%s:%d:%d|t"):format(file, width, height)
    end
    _G.CreateTextureMarkup = function(file, fileWidth, fileHeight, width, height, left, right, top, bottom)
        return ("|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d|t"):format(
            file,
            width,
            height,
            fileWidth,
            fileHeight,
            left * fileWidth,
            right * fileWidth,
            top * fileHeight,
            bottom * fileHeight
        )
    end
    -- Chattynator's saved settings: a profile per name, the character's current one by name.
    client.profile = { message_font_size = options.fontSize }
    _G.CHATTYNATOR_CONFIG = options.fontSize and { Profiles = { Mine = client.profile } } or nil
    _G.CHATTYNATOR_CURRENT_PROFILE = options.fontSize and "Mine" or nil
    _G.C_AddOns = {
        IsAddOnLoaded = function(name)
            return name == "ElvUI_EltreumUI" and options.eltruism == true
        end,
    }
    _G.GetNormalizedRealmName = function()
        return "Realm"
    end
    _G.GetRealmName = function()
        return "Realm"
    end
    -- In a raid the player has a raid unit too, after the members.
    _G.UnitName = function(unit)
        if unit == "player" or (client.raid and unit == "raid" .. (#client.group + 1)) then return "Me" end
        local m = member(unit)
        return m and m.name:match("^[^-]+"), m and m.name:match("-(.+)$")
    end
    _G.GetUnitName = function(unit)
        return unit == "player" and "Me" or nil
    end
    _G.UnitClass = function(unit)
        local m = member(unit)
        return "Class", "CLASS", unit == "player" and PLAYER_CLASS or m and m.classID
    end
    _G.UnitGUID = function(unit)
        return "guid-" .. unit
    end
    _G.UnitIsPlayer = function()
        return true
    end
    _G.UnitExists = function(unit)
        return unit == "player" or member(unit) ~= nil
    end
    _G.IsInGuild = function()
        return client.guild
    end
    _G.IsInGroup = function()
        return #client.group > 0
    end
    _G.IsInRaid = function()
        return #client.group > 0 and client.raid
    end
    _G.GetNumGroupMembers = function()
        return #client.group > 0 and #client.group + 1 or 0
    end
    _G.InCombatLockdown = function()
        return client.combat
    end
    _G.GetTime = function()
        return client.time
    end
    _G.CanInspect = function(unit)
        return member(unit).canInspect ~= false
    end
    _G.CheckInteractDistance = function(unit)
        return member(unit).inRange ~= false
    end
    _G.NotifyInspect = function(unit)
        table.insert(client.inspects, unit)
    end
    _G.ClearInspectPlayer = function()
        client.cleared = client.cleared + 1
    end
    _G.InspectFrame = nil
    _G.C_SpecializationInfo = {
        GetNumSpecializationsForClassID = function()
            return 3
        end,
        GetSpecializationInfo = function(index, isInspect)
            local source = isInspect and client.inspected or { classID = PLAYER_CLASS, trees = client.trees }
            local points = source.trees[index]
            return index, "Tree", "", source.classID * 100 + index, "DAMAGER", 1, points
        end,
    }
    _G.GetSpecializationInfoForSpecID = function(specId)
        return specId, "Spec", "", specId + 5000
    end
    _G.GetSpecializationInfoForClassID = function(classID, index)
        return index, "Tree", "", classID * 100 + index
    end
    local classFiles =
        { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", nil, "SHAMAN", "MAGE", "WARLOCK", nil, "DRUID" }
    _G.C_CreatureInfo = {
        GetClassInfo = function(classID)
            local file = classFiles[classID]
            return file and { className = file, classFile = file, classID = classID }
        end,
    }
    -- What the client knows about a GUID from LibClassicInspector's TALENTS_READY.
    client.players = {}
    _G.GetPlayerInfoByGUID = function(guid)
        local p = client.players[guid]
        return "Class", p.class, "Race", "RACE", 2, p.name, p.realm
    end
    _G.C_ChatInfo = {
        RegisterAddonMessagePrefix = function(prefix)
            client.prefix = prefix
        end,
        SendAddonMessage = function(prefix, text, channel)
            assert(prefix == client.prefix, "sent with an unregistered prefix")
            table.insert(client.sent, channel .. " " .. text)
        end,
    }
    _G.C_Timer = {
        After = function(_, fn)
            table.insert(client.timers, fn)
        end,
        NewTicker = function(interval, fn)
            client.ticker = { interval = interval, fn = fn }
        end,
    }

    -- LibStub with LibSpecialization where it runs: on Forever, not on Classic Era.
    local libs = {}
    if options.client == "forever" then
        local callbacks = {}
        client.lib = callbacks
        libs.LibSpecialization = {
            RegisterPlayerSpecChange = function(_, fn)
                callbacks.player = fn
            end,
            RegisterGuild = function(_, fn)
                callbacks.guild = fn
            end,
            RegisterGroup = function(_, fn)
                callbacks.group = fn
            end,
            MySpecialization = function()
                return client.specId
            end,
            RequestGuildSpecialization = function()
                client.guildRequests = client.guildRequests + 1
            end,
        }
    end
    if options.tacoTip then
        client.lciSpecs = {}
        libs.LibClassicInspector = {
            RegisterCallback = function(_, event, fn)
                client.lciCallbacks = client.lciCallbacks or {}
                client.lciCallbacks[event] = fn
            end,
            GetSpecialization = function(_, guid)
                local spec = client.lciSpecs[guid]
                return spec, spec and 31 or 0
            end,
        }
    end

    ---LibClassicInspector learns a player's talents.
    function client:TalentsReady(guid, class, name, realm, specIndex)
        self.players[guid] = { class = class, name = name, realm = realm }
        self.lciSpecs[guid] = specIndex
        self.lciCallbacks.TALENTS_READY("TALENTS_READY", guid, true)
    end

    _G.LibStub = function(name, silent)
        if not libs[name] and not silent then error("Cannot find a library instance of " .. name) end
        return libs[name]
    end

    local ns = {}
    client.ns = ns
    for _, file in ipairs(TOC_FILES) do
        assert(loadfile(file))("ChattynatorSpecialisationIcons", ns)
    end
    client:Fire("PLAYER_LOGIN")
    client.player = PLAYER
    return client
end
