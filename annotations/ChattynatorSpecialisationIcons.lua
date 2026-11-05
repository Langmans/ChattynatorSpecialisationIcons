---@meta
-- Types for the editor and the WoW Lua LS: the other addons and libraries this one talks to.

---@class ChattynatorPlayer
---@field name string? "Name-Realm"

---@class ChattynatorTypeInfo
---@field player ChattynatorPlayer?

---@class ChattynatorMessage
---@field text string
---@field typeInfo ChattynatorTypeInfo

---@class ChattynatorAPI
---@field AddModifier fun(modifier: fun(data: ChattynatorMessage))

---@class Chattynator
---@field API ChattynatorAPI
Chattynator = {}

---@class DLAPI _DebugLog
---@field DebugLog fun(category: string, text: string)
DLAPI = {}

---@alias LibSpecializationCallback fun(specId: number, role: string, position: string, name: string, talentString: string?)

---@class LibSpecialization
---@field RegisterPlayerSpecChange fun(owner: table, callback: fun())
---@field RegisterGuild fun(owner: table, callback: LibSpecializationCallback)
---@field RegisterGroup fun(owner: table, callback: LibSpecializationCallback)
---@field MySpecialization fun(): number? spec ID (on Forever a talent group ID), nil before a point is spent
---@field RequestGuildSpecialization fun()

---TacoTip's LibClassicInspector, the part this addon uses.
---@class LibClassicInspector
---@field RegisterCallback fun(owner: table, event: "TALENTS_READY", callback: fun(event: string, guid: string, isInspect: boolean, unit: string?))
local LibClassicInspector = {}

---The tree with the most points, nil while the lib knows none.
---@param unitOrGuid string
---@return number? tree
---@return number points
function LibClassicInspector:GetSpecialization(unitOrGuid) end

---@class ChattynatorSpecialisationIconsNS
---@field FullName fun(name: string): string
---@field SetIcon fun(name: string, icon: number?)
---@field HasIcon fun(name: string): boolean
