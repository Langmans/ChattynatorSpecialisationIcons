-- Puts a player's specialisation icon inside their name link in Chattynator. The icons come from
-- LibSpecialization where it runs (Retail, Forever); Era.lua finds them on Classic Era.
local addonName = ... ---@type string
local ns = select(2, ...) ---@type ChattynatorSpecialisationIconsNS

local LibSpecialization = LibStub("LibSpecialization", true) ---@type LibSpecialization?
local CreateSimpleTextureMarkup = CreateSimpleTextureMarkup
local GetNormalizedRealmName = GetNormalizedRealmName
local GetRealmName = GetRealmName
local format = format
local gsub = gsub
local pcall = pcall
local tostring = tostring
local DLAPI = DLAPI ---@type DLAPI?
local Chattynator = Chattynator

local function debug(...)
    if DLAPI then
        local ok, text = pcall(format, ...)
        if ok then DLAPI.DebugLog(addonName, text) end
    end
end

-- With Eltruism loaded, its spec icons (made for Details) replace the game's. The file stays
-- Eltruism's: it is used from Eltruism's folder, never copied. It is an 8 by 8 grid of 64 pixel
-- cells in Details' layout, by specialisation ID as Retail numbers them.
local ELTRUISM = "ElvUI_EltreumUI"
local ELTRUISM_ICONS = "Interface\\AddOns\\ElvUI_EltreumUI\\Media\\Details\\spec_icons_eltruism.tga"
local ATLAS_SIZE, ATLAS_CELLS = 512, 8
-- Eltruism's icon is as tall as Chattynator's message font: a size of 0 in the markup is the font
-- object's own height, not the size Chattynator sets, and the icon came out small at the line's
-- top. Chattynator's default size, for before its profile is read.
local DEFAULT_FONT_SIZE = 14
-- Per specialisation ID, its cell as column + row * ATLAS_CELLS.
---@type table<number, number>
local ATLAS_CELL = {
    [250] = 0,
    [251] = 1,
    [252] = 2, -- Death Knight
    [102] = 3,
    [103] = 4,
    [104] = 5,
    [105] = 6, -- Druid
    [253] = 7,
    [254] = 8,
    [255] = 9, -- Hunter
    [62] = 10,
    [63] = 11,
    [64] = 12, -- Mage
    [268] = 13,
    [270] = 14,
    [269] = 15, -- Monk
    [65] = 16,
    [66] = 17,
    [70] = 18, -- Paladin
    [256] = 19,
    [257] = 20,
    [258] = 21, -- Priest
    [259] = 22,
    [260] = 23,
    [261] = 24, -- Rogue
    [262] = 25,
    [263] = 26,
    [264] = 27, -- Shaman
    [265] = 28,
    [266] = 29,
    [267] = 30, -- Warlock
    [71] = 31,
    [72] = 32,
    [73] = 33, -- Warrior
    [577] = 34,
    [581] = 35, -- Demon Hunter
    [1467] = 36,
    [1468] = 37,
    [1473] = 38, -- Evoker
    [1480] = 39, -- Demon Hunter, Devourer
}

---Per icon file, the specialisation it stands for (Retail's IDs), where known: from
---LibSpecialization, or from a Classic Era tree (Era.lua).
---@type table<number, number>
ns.specOfIcon = {}

---Chattynator's message font size ("Message font size"), from its current profile; its default
---before the profile is there.
---@return number
local function fontSize()
    local config = rawget(_G, "CHATTYNATOR_CONFIG") --[[@as {Profiles: table<string, {message_font_size: number?}>?}?]]
    local profiles = config and config.Profiles
    local profile = profiles and profiles[rawget(_G, "CHATTYNATOR_CURRENT_PROFILE") or "DEFAULT"]
    return profile and profile.message_font_size or DEFAULT_FONT_SIZE
end

---Chat markup for an icon: Eltruism's version of it when Eltruism is loaded and has one, else the
---game's.
---@param icon number
---@param size number Eltruism's icon's size: the chat's font size
---@return string
local function markupOf(icon, size)
    local cell = ATLAS_CELL[ns.specOfIcon[icon]]
    if not cell or not C_AddOns.IsAddOnLoaded(ELTRUISM) then return CreateSimpleTextureMarkup(icon, 0, 0) end
    local column, row = cell % ATLAS_CELLS, math.floor(cell / ATLAS_CELLS)
    local left, top = column / ATLAS_CELLS, row / ATLAS_CELLS
    local cellSize = 1 / ATLAS_CELLS
    return CreateTextureMarkup(
        ELTRUISM_ICONS,
        ATLAS_SIZE,
        ATLAS_SIZE,
        size,
        size,
        left,
        left + cellSize,
        top,
        top + cellSize
    )
end

-- Chat markup per icon file, built once per icon and font size: a new size starts a new set.
---@type table<number, string>
local markups = {}
local markupSize ---@type number?

---@param icon number
---@return string
local function markupFor(icon)
    local size = fontSize()
    if size ~= markupSize then
        markups, markupSize = {}, size
    end
    local markup = markups[icon]
    if not markup then
        markup = markupOf(icon, size)
        markups[icon] = markup
    end
    return markup
end

---@type table<string, number> icon file per "Name-Realm"
local playerIcons = {}

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
    if playerIcons[name] ~= icon then
        playerIcons[name] = icon
        debug("%s: %s", name, tostring(icon and markupFor(icon)))
    end
end

---@param name string
---@return boolean
function ns.HasIcon(name)
    return playerIcons[ns.FullName(name)] ~= nil
end

---@param data ChattynatorMessage
local function addIcon(data)
    local player = data.typeInfo.player
    -- Chattynator names a player on the own realm without the realm (Ambiguate "none").
    local icon = player and player.name and playerIcons[ns.FullName(player.name)] ---@type number?
    if icon then data.text = gsub(data.text, "(|Hplayer:[^|]+|h)(%[?)", "%1%2" .. markupFor(icon)) end
end
Chattynator.API.AddModifier(addIcon)

if not LibSpecialization then return end
local Lib = LibSpecialization ---@type LibSpecialization

local GetSpecializationInfoForSpecID = GetSpecializationInfoForSpecID
local GetUnitName = GetUnitName

---@param name string
---@param specId number
local function setSpec(name, specId)
    local _, _, _, icon = GetSpecializationInfoForSpecID(specId)
    if icon then ns.specOfIcon[icon] = specId end
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
