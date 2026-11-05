-- Puts a player's specialisation icon inside their name link in Chattynator. The icons come from
-- LibSpecialization where it runs (Retail, Mists, Forever); Era.lua finds them on Classic Era and TBC.
local addonName = ... ---@type string
local ns = select(2, ...) ---@type ChattynatorSpecialisationIconsNS

local LibSpecialization = LibStub("LibSpecialization", true) ---@type LibSpecialization?
local CreateSimpleTextureMarkup = CreateSimpleTextureMarkup
local GetNormalizedRealmName = GetNormalizedRealmName
local GetRealmName = GetRealmName
local format = format
local gsub = gsub
local pcall = pcall
local setmetatable = setmetatable
local tostring = tostring
local DLAPI = DLAPI ---@type DLAPI?
local Chattynator = Chattynator

local function debug(...)
    if DLAPI then
        local ok, text = pcall(format, ...)
        if ok then DLAPI.DebugLog(addonName, text) end
    end
end

---Chat markup per icon file, built once per icon.
---@type table<number, string>
local markups = setmetatable({}, {
    ---@param self table<number, string>
    ---@param icon number
    ---@return string
    __index = function(self, icon)
        local markup = CreateSimpleTextureMarkup(icon, 0, 0)
        self[icon] = markup
        return markup
    end,
})

---@type table<string, string> markup per "Name-Realm"
local playerMarkups = {}

---"Name-Realm" for a name that may come without its realm.
---@param name string
---@return string
function ns.FullName(name)
    if name:find("-", 1, true) then return name end
    return name .. "-" .. (GetNormalizedRealmName() or GetRealmName():gsub("[%s%-]", ""))
end

---Sets the icon shown for a player, or removes it with nil.
---@param name string
---@param icon number? file ID
function ns.SetIcon(name, icon)
    name = ns.FullName(name)
    local markup = icon and markups[icon] or nil ---@type string?
    if playerMarkups[name] ~= markup then
        playerMarkups[name] = markup
        debug("%s: %s", name, tostring(markup))
    end
end

---@param name string
---@return boolean
function ns.HasIcon(name)
    return playerMarkups[ns.FullName(name)] ~= nil
end

---@param data ChattynatorMessage
local function addIcon(data)
    local player = data.typeInfo.player
    -- Chattynator names a player on the own realm without the realm (Ambiguate "none").
    local markup = player and player.name and playerMarkups[ns.FullName(player.name)] ---@type string?
    if markup then data.text = gsub(data.text, "(|Hplayer:[^|]+|h)(%[?)", "%1%2" .. markup) end
end
Chattynator.API.AddModifier(addIcon)

if not LibSpecialization then return end
local Lib = LibSpecialization ---@type LibSpecialization

local GetSpecializationInfoForSpecID = GetSpecializationInfoForSpecID
local GetUnitName = GetUnitName

-- WoW Forever has one spec per class, so LibSpecialization reports the talent group (tree) with the
-- most points instead, and the game has no lookup from a group ID to its icon for other players'
-- classes. Icon file IDs from Forever's game data: each group's talents belong to a talent tree
-- skill line (SkillLineAbility), whose SpellIconFileID is the tree's icon.
---@type table<number, number> icon file ID per talent group ID
local TREE_ICONS = {
    [11582] = 135932, -- Mage: Arcane
    [11594] = 135810, -- Mage: Fire
    [11601] = 135846, -- Mage: Frost
    [11328] = 136096, -- Druid: Balance
    [11347] = 132276, -- Druid: Feral Combat
    [11340] = 136041, -- Druid: Restoration
    [11372] = 132164, -- Hunter: Beast Mastery
    [11371] = 132222, -- Hunter: Marksmanship
    [11370] = 132215, -- Hunter: Survival
    [11486] = 135920, -- Paladin: Holy
    [11541] = 135893, -- Paladin: Protection
    [11559] = 135873, -- Paladin: Retribution
    [11608] = 135987, -- Priest: Discipline
    [11615] = 135920, -- Priest: Holy
    [11622] = 136207, -- Priest: Shadow Magic
    [11580] = 132292, -- Rogue: Assassination
    [11573] = 132090, -- Rogue: Combat
    [11572] = 132320, -- Rogue: Subtlety
    [11326] = 136048, -- Shaman: Elemental Combat
    [11363] = 136051, -- Shaman: Enhancement
    [11362] = 136052, -- Shaman: Restoration
    [11629] = 136145, -- Warlock: Affliction
    [11636] = 136172, -- Warlock: Demonology
    [11637] = 136186, -- Warlock: Destruction
    [11650] = 132292, -- Warrior: Arms
    [11657] = 132347, -- Warrior: Fury
    [11670] = 132341, -- Warrior: Protection
}

---Sets a player's icon from what LibSpecialization reports.
---@param name string
---@param specId number? a spec ID, on Forever a talent group ID; nil before a point is spent
local function setSpec(name, specId)
    local icon = TREE_ICONS[specId] ---@type number?
    if not icon and specId then
        local _, _, _, specIcon = GetSpecializationInfoForSpecID(specId)
        icon = specIcon
    end
    ns.SetIcon(name, icon)
end

local function updatePlayerSpec()
    setSpec(GetUnitName("player", true), Lib.MySpecialization())
end

---@param specId number
---@param role string
---@param position string
---@param name string
local function onSpec(specId, role, position, name)
    setSpec(name, specId)
end

---@param owner number EventRegistry's owner ID
---@param canRequestRosterUpdate boolean
local function onGuildRoster(owner, canRequestRosterUpdate)
    if canRequestRosterUpdate then Lib.RequestGuildSpecialization() end
end

EventRegistry:RegisterFrameEventAndCallback("PLAYER_LOGIN", function()
    Lib.RegisterPlayerSpecChange(ns, updatePlayerSpec)
    Lib.RegisterGuild(ns, onSpec)
    Lib.RegisterGroup(ns, onSpec)
    updatePlayerSpec()
    Lib.RequestGuildSpecialization()
    EventRegistry:RegisterFrameEventAndCallback("GUILD_ROSTER_UPDATE", onGuildRoster)
end)
