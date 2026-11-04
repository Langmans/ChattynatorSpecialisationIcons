-- Classic Era has talent trees, not specialisations, and LibSpecialization does not run there.
-- A player's icon is that of their tree with the most points. Sources, see README:
--   the player's own trees; this addon's message from guild and group members who run it too;
--   TacoTip's LibClassicInspector when loaded, else an inspect of group members in range.
local ns = select(2, ...) ---@type ChattynatorSpecialisationIconsNS

if LibStub("LibSpecialization", true) then return end

local Inspector = LibStub("LibClassicInspector", true) ---@type LibClassicInspector?
local GetSpecializationInfo = C_SpecializationInfo.GetSpecializationInfo
local GetNumSpecializationsForClassID = C_SpecializationInfo.GetNumSpecializationsForClassID
local SendAddonMessage = C_ChatInfo.SendAddonMessage
local After = C_Timer.After
local CanInspect = CanInspect
local CheckInteractDistance = CheckInteractDistance
local ClearInspectPlayer = ClearInspectPlayer
local GetNumGroupMembers = GetNumGroupMembers
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local IsInGroup = IsInGroup
local IsInGuild = IsInGuild
local IsInRaid = IsInRaid
local NotifyInspect = NotifyInspect
local UnitClass = UnitClass
local UnitGUID = UnitGUID
local UnitIsPlayer = UnitIsPlayer
local UnitName = UnitName
local tonumber = tonumber

local PREFIX = "ChattySpecIcon"
local REQUEST = "R"
local REPLY_DELAY = 3 -- seconds; several requests on one channel get one answer
local INSPECT_INTERVAL = 2
local INSPECT_TIMEOUT = 5 -- an inspect not answered by then is given up

local CHECK_INSPECT_RANGE = 1 -- CheckInteractDistance's index for inspect range

-- Group unit tokens, built once.
local PARTY_UNITS, RAID_UNITS = {}, {}
for i = 1, 4 do
    PARTY_UNITS[i] = "party" .. i
end
for i = 1, 40 do
    RAID_UNITS[i] = "raid" .. i
end

local playerName ---@type string
local playerIcon ---@type number?

---Icon of the tree with the most points, the first of equals; nil before a point is spent.
---@param classID number
---@param isInspect boolean the inspected unit's trees instead of the player's
---@return number?
local function topTreeIcon(classID, isInspect)
    local bestIcon, bestPoints = nil, 0
    for i = 1, GetNumSpecializationsForClassID(classID) do
        local _, _, _, icon, _, _, points = GetSpecializationInfo(i, isInspect, false)
        if points > bestPoints then
            bestIcon, bestPoints = icon, points
        end
    end
    return bestIcon
end

---@return string? channel the group's addon channel, nil outside a group
local function groupChannel()
    return IsInRaid() and "RAID" or IsInGroup() and "PARTY" or nil
end

---@return string
local function state()
    return "S:" .. (playerIcon or "")
end

---Sends text to the guild and the group, where the player is in them.
---@param text string
local function broadcast(text)
    if IsInGuild() then SendAddonMessage(PREFIX, text, "GUILD") end
    local group = groupChannel()
    if group then SendAddonMessage(PREFIX, text, group) end
end

---Reads the player's top tree. Returns whether the icon changed.
---@return boolean
local function readPlayer()
    local _, _, classID = UnitClass("player")
    local icon = topTreeIcon(classID, false)
    if icon == playerIcon then return false end
    playerIcon = icon
    ns.SetIcon(playerName, icon)
    return true
end

local function updatePlayer()
    if readPlayer() then broadcast(state()) end
end

-- Answers to requests, one per channel.
local replyPending = {} ---@type table<string, true>
local replies = {} ---@type table<string, fun()>
for _, channel in ipairs({ "GUILD", "PARTY", "RAID" }) do
    replies[channel] = function()
        replyPending[channel] = nil
        SendAddonMessage(PREFIX, state(), channel)
    end
end

---@param owner number EventRegistry's owner ID
---@param prefix string
---@param text string
---@param channel string
---@param sender string "Name-Realm"
local function onAddonMessage(owner, prefix, text, channel, sender)
    if prefix ~= PREFIX or ns.FullName(sender) == playerName then return end
    if text == REQUEST then
        if replies[channel] and not replyPending[channel] then
            replyPending[channel] = true
            After(REPLY_DELAY, replies[channel])
        end
        return
    end
    local digits = text:match("^S:(%d*)$") ---@type string?
    if digits then
        local icon = tonumber(digits)
        ns.SetIcon(sender, icon and icon > 0 and icon or nil)
    end
end

local wasInGroup = false

local function onGroupChanged()
    local group = groupChannel()
    if group and not wasInGroup then
        SendAddonMessage(PREFIX, state(), group)
        SendAddonMessage(PREFIX, REQUEST, group)
    end
    wasInGroup = group ~= nil
end

-- Inspecting group members, one at a time, each once per session.
local inspected = {} ---@type table<string, true>
-- The inspect sent and not yet answered: its GUID (nil when none), name, unit and time.
local pendingGUID, pendingName, pendingUnit, pendingSince

local function inspectWindowOpen()
    return InspectFrame and InspectFrame:IsShown()
end

---Whether unit is a group member to inspect now.
---@param unit string
---@return string? name
local function inspectable(unit)
    if not UnitIsPlayer(unit) then return end
    local name = ns.FullName((UnitName(unit)))
    if
        name ~= playerName
        and not inspected[name]
        and not ns.HasIcon(name)
        and CanInspect(unit)
        and CheckInteractDistance(unit, CHECK_INSPECT_RANGE)
    then
        return name
    end
end

local function inspectNext()
    if pendingGUID and GetTime() - pendingSince < INSPECT_TIMEOUT then return end
    pendingGUID = nil
    if InCombatLockdown() or inspectWindowOpen() then return end
    local units, count = PARTY_UNITS, GetNumGroupMembers() - 1
    if IsInRaid() then
        units, count = RAID_UNITS, count + 1
    end
    for i = 1, count do
        local unit = units[i]
        local name = inspectable(unit)
        if name then
            pendingGUID, pendingName, pendingUnit, pendingSince = UnitGUID(unit), name, unit, GetTime()
            NotifyInspect(unit)
            return
        end
    end
end

---@param owner number EventRegistry's owner ID
---@param guid string
local function onInspectReady(owner, guid)
    if guid ~= pendingGUID then return end
    local _, _, classID = UnitClass(pendingUnit)
    local icon = topTreeIcon(classID, true)
    if icon then ns.SetIcon(pendingName, icon) end
    inspected[pendingName] = true
    pendingGUID = nil
    if not inspectWindowOpen() then ClearInspectPlayer() end
end

-- TacoTip's LibClassicInspector reports a tree index; the icon comes from the class.
local classIDs = {} ---@type table<string, number> classFile to class ID
for classID = 1, 20 do
    local info = C_CreatureInfo.GetClassInfo(classID)
    if info then classIDs[info.classFile] = classID end
end

---@param event string
---@param guid string
local function onTalentsReady(event, guid)
    local tree = (Inspector --[[@as LibClassicInspector]]):GetSpecialization(guid)
    if not tree then return end
    local _, classFile, _, _, _, name, realm = GetPlayerInfoByGUID(guid)
    local _, _, _, icon = GetSpecializationInfoForClassID(classIDs[classFile], tree)
    ns.SetIcon(realm ~= "" and name .. "-" .. realm or name, icon)
end

EventRegistry:RegisterFrameEventAndCallback("PLAYER_LOGIN", function()
    playerName = ns.FullName((UnitName("player")))
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    EventRegistry:RegisterFrameEventAndCallback("CHAT_MSG_ADDON", onAddonMessage)
    EventRegistry:RegisterFrameEventAndCallback("GROUP_ROSTER_UPDATE", onGroupChanged)
    for _, event in ipairs({ "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED" }) do
        EventRegistry:RegisterFrameEventAndCallback(event, updatePlayer)
    end

    -- The player's own state first, then a request for everyone else's.
    readPlayer()
    broadcast(state())
    wasInGroup = groupChannel() ~= nil
    broadcast(REQUEST)

    if Inspector then
        Inspector.RegisterCallback(ns, "TALENTS_READY", onTalentsReady)
    else
        EventRegistry:RegisterFrameEventAndCallback("INSPECT_READY", onInspectReady)
        C_Timer.NewTicker(INSPECT_INTERVAL, inspectNext)
    end
end)
