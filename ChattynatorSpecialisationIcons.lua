local addonName, ns = ...

local pcall = pcall
local format = format
local LibSpecialization = LibStub("LibSpecialization")

---@diagnostic disable-next-line: undefined-global
local DLAPI = DLAPI
---@diagnostic disable-next-line: undefined-global
local Chattynator = Chattynator

local function debug(...)
    if DLAPI then
        local status, result = pcall(format, ...)
        if status then
            DLAPI.DebugLog(addonName, result)
        end
    end
end

local playerIcons = {}

-- simple metatable to cache spec icons
local icons
do
    local CreateSimpleTextureMarkup = CreateSimpleTextureMarkup
    local GetSpecializationInfoForSpecID = GetSpecializationInfoForSpecID
    icons = setmetatable({}, {
        __mode = "kv",
        __index = function(self, key)
            --local id, name, description, icon, role = GetSpecializationInfoForSpecID(key)
            --debug('spec~id=%q, name=%q, description=%q, icon=%q, role=%q', id, name, description, icon, role)

            local _, _, _, icon = GetSpecializationInfoForSpecID(key)
            local markup = CreateSimpleTextureMarkup(icon, 0, 0)
            debug('icons~%q=%q', key, markup)
            self[key] = markup
            return self[key]
        end
    })
end

local disambiguatePlayerName
do
    local GetNormalizedRealmName = GetNormalizedRealmName
    local GetRealmName = GetRealmName
    function disambiguatePlayerName(playerName)
        if not playerName:find("-") then
            playerName = playerName .. '-' .. (GetNormalizedRealmName or GetRealmName)():gsub("[%s%-]", "")
        end

        return playerName
    end
end

local function update(channel, playerName, specId)
    local icon = icons[specId]
    if not playerIcons[playerName] or playerIcons[playerName] ~= icon then
        debug('%s~playerName=%q, specId=%q, icon=%s', channel, playerName, specId, icon)
        playerIcons[playerName] = icons[specId]
    end
end

local updatePlayerSpec
do
    local GetUnitName = GetUnitName
    function updatePlayerSpec()
        update('player', disambiguatePlayerName(GetUnitName("player", true)), LibSpecialization.MySpecialization())
    end
end

local buildSpecialisationInfoReceiver = function(channel)
    return function(specId, _, _, playerName)
        update(channel, disambiguatePlayerName(playerName), specId)
    end
end

EventRegistry:RegisterFrameEventAndCallback("PLAYER_LOGIN", function()
    LibSpecialization.RegisterPlayerSpecChange(ns, updatePlayerSpec)
    LibSpecialization.RegisterGuild(ns, buildSpecialisationInfoReceiver('guild'))
    LibSpecialization.RegisterGroup(ns, buildSpecialisationInfoReceiver('group'))

    updatePlayerSpec()
    LibSpecialization.RequestGuildSpecialization()

    EventRegistry:RegisterFrameEventAndCallback("GUILD_ROSTER_UPDATE", function(_, canRequestRosterUpdate)
        debug('guild~GUILD_ROSTER_UPDATE, canRequestRosterUpdate=%q', canRequestRosterUpdate or false)
        if canRequestRosterUpdate then
            LibSpecialization.RequestGuildSpecialization()
        end
    end)

end)

Chattynator.API.AddModifier(function(data)
    local playerName = data.typeInfo.player and data.typeInfo.player.name
    local icon = playerName and playerIcons[playerName]
	if icon then
		debug('modifier~name=%q, icon=%q', playerName, icon)
		data.text = gsub(data.text, "(|Hplayer:[^|]+|h)(%[?)", "%1%2" .. icon)

		--Debug("race = %q, sex = %q, icon = %q", race, sex, icon)
	end
end)
