-- Which icon a player gets in Chattynator, and where it comes from on each client.
-- The player is a Paladin (class 2), so their tree icons are 201 to 203; see tests/wow.lua.

local WARRIOR = 1

---@return TestMember
local function bob(fields)
    local m = { unit = "party1", name = "Bob-Realm", classID = WARRIOR, trees = { 31, 20, 0 } }
    for k, v in pairs(fields or {}) do
        m[k] = v
    end
    return m
end

local function icon(file)
    return ("|T%d:0:0|t"):format(file)
end

describe("the chat line", function()
    it("gets the icon just inside the player link's bracket", function()
        local client = NewClient()
        assert.equal("|Hplayer:Me-Realm:1:GUILD|h[" .. icon(203) .. "Me]|h: hello", client:Chat("Me-Realm"))
    end)

    it("finds a player on the own realm, whom Chattynator names without the realm", function()
        local client = NewClient()
        assert.equal("|Hplayer:Me:1:GUILD|h[" .. icon(203) .. "Me]|h: hello", client:Chat("Me"))
    end)

    it("stays as it is for a player without a known icon", function()
        local client = NewClient()
        assert.equal("|Hplayer:Bob-Realm:1:GUILD|h[Bob]|h: hello", client:Chat("Bob-Realm"))
    end)

    it("logs a new icon to _DebugLog when that is loaded", function()
        local client = NewClient({ debugLog = true })
        assert.same({ "Me-Realm: " .. icon(203) }, client.logged)
    end)
end)

describe("with Eltruism loaded", function()
    ---Eltruism's spec icon in the cell at column, row of its 8 by 8 atlas, `size` tall (14 by default).
    local function eltruism(column, row, size)
        return ("|TInterface\\AddOns\\ElvUI_EltreumUI\\Media\\Details\\spec_icons_eltruism.tga:%d:%d:0:0:512:512:%d:%d:%d:%d|t"):format(
            size or 14,
            size or 14,
            column * 64,
            column * 64 + 64,
            row * 64,
            row * 64 + 64
        )
    end

    it("shows Eltruism's icon of a Classic Era tree, by class and tree", function()
        local client = NewClient({ eltruism = true })
        assert.equal(eltruism(2, 2), client:Icon("Me-Realm"), "a Paladin's third tree: Retribution")
        client:Receive("Bob-Realm", "S:101")
        assert.equal(eltruism(7, 3), client:Icon("Bob-Realm"), "a Warrior's first tree: Arms")
        client:Receive("Bob-Realm", "S:1103")
        assert.equal(eltruism(6, 0), client:Icon("Bob-Realm"), "a Druid's third tree: Restoration")
    end)

    it("shows Eltruism's icon of a specialisation", function()
        local client = NewClient({ client = "forever", eltruism = true, specId = 254 })
        assert.equal(eltruism(0, 1), client:Icon("Me-Realm"), "Marksmanship")
    end)

    it("is as tall as Chattynator's message font, also after it changes", function()
        local client = NewClient({ eltruism = true, fontSize = 19 })
        assert.equal(eltruism(2, 2, 19), client:Icon("Me-Realm"))
        client.profile.message_font_size = 24
        assert.equal(eltruism(2, 2, 24), client:Icon("Me-Realm"))
    end)

    it("keeps the game's icon for one Eltruism has none of", function()
        local client = NewClient({ eltruism = true })
        client:Receive("Bob-Realm", "S:132")
        assert.equal(icon(132), client:Icon("Bob-Realm"))
        assert.equal(
            icon(9999 + 5000),
            NewClient({ client = "forever", eltruism = true, specId = 9999 }):Icon("Me-Realm")
        )
    end)
end)

describe("on Classic Era, the player's own icon", function()
    it("is the tree with the most points", function()
        assert.equal(icon(203), NewClient():Icon("Me-Realm"))
        assert.equal(icon(201), NewClient({ trees = { 21, 0, 30 - 21 } }):Icon("Me-Realm"))
    end)

    it("is the first of two trees with equal points", function()
        assert.equal(icon(201), NewClient({ trees = { 10, 10, 0 } }):Icon("Me-Realm"))
    end)

    it("is none before a point is spent", function()
        assert.is_nil(NewClient({ trees = { 0, 0, 0 } }):Icon("Me-Realm"))
    end)

    it("follows a talent change and tells the guild", function()
        local client = NewClient()
        client:TakeSent()
        client.trees = { 31, 0, 0 }
        client:Fire("CHARACTER_POINTS_CHANGED", -1)
        assert.equal(icon(201), client:Icon("Me-Realm"))
        assert.same({ "GUILD S:201" }, client:TakeSent())
    end)

    it("follows a switch to the other talent group", function()
        local client = NewClient()
        client.trees = { 0, 40, 11 }
        client:Fire("ACTIVE_TALENT_GROUP_CHANGED", 2, 1)
        assert.equal(icon(202), client:Icon("Me-Realm"))
    end)

    it("tells nobody when the talent update changes nothing", function()
        local client = NewClient()
        client:TakeSent()
        client:Fire("PLAYER_TALENT_UPDATE")
        assert.same({}, client:TakeSent())
    end)
end)

describe("on Classic Era, the addon's message", function()
    it("goes to the guild at login: the player's icon, then a request for theirs", function()
        assert.same({ "GUILD S:203", "GUILD R" }, NewClient():TakeSent())
    end)

    it("says no icon before a point is spent", function()
        assert.same({ "GUILD S:", "GUILD R" }, NewClient({ trees = { 0, 0, 0 } }):TakeSent())
    end)

    it("goes to the group too when logging in grouped", function()
        local sent = NewClient({ group = { bob() } }):TakeSent()
        assert.same({ "GUILD S:203", "PARTY S:203", "GUILD R", "PARTY R" }, sent)
    end)

    it("goes nowhere outside a guild and group", function()
        assert.same({}, NewClient({ guild = false }):TakeSent())
    end)

    it("goes to the party on joining one, and not again on its next changes", function()
        local client = NewClient({ guild = false })
        client.group = { bob() }
        client:Fire("GROUP_ROSTER_UPDATE")
        assert.same({ "PARTY S:203", "PARTY R" }, client:TakeSent())
        table.insert(client.group, bob({ unit = "party2", name = "Ann-Realm" }))
        client:Fire("GROUP_ROSTER_UPDATE")
        assert.same({}, client:TakeSent())
    end)

    it("goes to the raid on joining one", function()
        local client = NewClient({ guild = false })
        client.group, client.raid = { bob({ unit = "raid1" }) }, true
        client:Fire("GROUP_ROSTER_UPDATE")
        assert.same({ "RAID S:203", "RAID R" }, client:TakeSent())
    end)

    it("goes to the group again after leaving and joining another", function()
        local client = NewClient({ guild = false, group = { bob() } })
        client.group = {}
        client:Fire("GROUP_ROSTER_UPDATE")
        client:TakeSent()
        client.group = { bob() }
        client:Fire("GROUP_ROSTER_UPDATE")
        assert.same({ "PARTY S:203", "PARTY R" }, client:TakeSent())
    end)

    it("from someone else sets their icon", function()
        local client = NewClient()
        client:Receive("Bob-Realm", "S:132")
        assert.equal(icon(132), client:Icon("Bob-Realm"))
    end)

    it("from someone else without an icon clears theirs", function()
        local client = NewClient()
        client:Receive("Bob-Realm", "S:132")
        client:Receive("Bob-Realm", "S:")
        assert.is_nil(client:Icon("Bob-Realm"))
    end)

    it("is ignored when it is not one of ours or not well formed", function()
        local client = NewClient()
        client:Receive("Bob-Realm", "S:132", "GUILD", "OtherAddon")
        client:Receive("Bob-Realm", "S:abc")
        client:Receive("Bob-Realm", "S:0")
        assert.is_nil(client:Icon("Bob-Realm"))
    end)

    it("asking for ours gets one answer per channel, after a short wait", function()
        local client = NewClient({ group = { bob() } })
        client:TakeSent()
        client:Receive("Bob-Realm", "R", "GUILD")
        client:Receive("Ann-Realm", "R", "GUILD")
        client:Receive("Bob-Realm", "R", "PARTY")
        assert.same({}, client:TakeSent())
        client:RunTimers()
        assert.same({ "GUILD S:203", "PARTY S:203" }, client:TakeSent())
        client:Receive("Bob-Realm", "R", "GUILD")
        client:RunTimers()
        assert.same({ "GUILD S:203" }, client:TakeSent())
    end)

    it("from the player, echoed back by the server, is ignored", function()
        local client = NewClient()
        client:TakeSent()
        client:Receive("Me-Realm", "R")
        client:Receive("Me-Realm", "S:")
        client:RunTimers()
        assert.same({}, client:TakeSent())
        assert.equal(icon(203), client:Icon("Me-Realm"))
    end)
end)

describe("on Classic Era, inspecting", function()
    it("asks for a group member without an icon and takes their top tree", function()
        local client = NewClient({ group = { bob() } })
        client:Wait(2)
        assert.same({ "party1" }, client.inspects)
        client:InspectReady()
        assert.equal(icon(101), client:Icon("Bob-Realm"))
        assert.equal(1, client.cleared)
    end)

    it("goes through a raid's members, never the player's own raid unit", function()
        local client = NewClient({ group = { bob({ unit = "raid1" }) }, raid = true })
        client:Wait(2)
        client:InspectReady()
        client:Wait(10)
        assert.same({ "raid1" }, client.inspects)
        assert.equal(icon(101), client:Icon("Bob-Realm"))
    end)

    it("does one member at a time", function()
        local client = NewClient({ group = { bob(), bob({ unit = "party2", name = "Ann-Realm" }) } })
        client:Wait(4)
        assert.same({ "party1" }, client.inspects)
        client:InspectReady()
        client:Wait(2)
        assert.same({ "party1", "party2" }, client.inspects)
    end)

    it("does each member once, even when they have no points", function()
        local client = NewClient({ group = { bob({ trees = { 0, 0, 0 } }) } })
        client:Wait(2)
        client:InspectReady()
        client:Wait(10)
        assert.same({ "party1" }, client.inspects)
        assert.is_nil(client:Icon("Bob-Realm"))
    end)

    it("gives up on an answer that does not come and tries again later", function()
        local client = NewClient({ group = { bob() } })
        client:Wait(2)
        client:Wait(10)
        assert.same({ "party1", "party1" }, client.inspects)
    end)

    it("skips members whose icon came by message", function()
        local client = NewClient({ group = { bob() } })
        client:Receive("Bob-Realm", "S:132", "PARTY")
        client:Wait(10)
        assert.same({}, client.inspects)
    end)

    it("waits for members out of range, or who cannot be inspected", function()
        local far = bob({ inRange = false })
        local client = NewClient({ group = { far, bob({ unit = "party2", name = "Ann-Realm", canInspect = false }) } })
        client:Wait(10)
        assert.same({}, client.inspects)
        far.inRange = true
        client:Wait(2)
        assert.same({ "party1" }, client.inspects)
    end)

    it("waits in combat", function()
        local client = NewClient({ group = { bob() } })
        client.combat = true
        client:Wait(10)
        assert.same({}, client.inspects)
    end)

    it("waits while the player has Blizzard's inspect window open", function()
        local client = NewClient({ group = { bob() } })
        _G.InspectFrame = {
            IsShown = function()
                return true
            end,
        }
        client:Wait(10)
        assert.same({}, client.inspects)
    end)

    it("leaves an answer for someone the player inspects alone", function()
        local client = NewClient({ group = { bob() } })
        client:Wait(2)
        client:InspectReady("party2")
        assert.is_nil(client:Icon("Bob-Realm"))
        assert.equal(0, client.cleared)
    end)

    it("leaves the inspect open when the player opened Blizzard's window meanwhile", function()
        local client = NewClient({ group = { bob() } })
        client:Wait(2)
        _G.InspectFrame = {
            IsShown = function()
                return true
            end,
        }
        client:InspectReady()
        assert.equal(icon(101), client:Icon("Bob-Realm"))
        assert.equal(0, client.cleared)
    end)

    it("does nothing outside a group", function()
        local client = NewClient()
        client:Wait(10)
        assert.same({}, client.inspects)
    end)
end)

describe("on Classic Era with TacoTip's LibClassicInspector", function()
    it("takes the icon of the tree the lib reports for a player", function()
        local client = NewClient({ tacoTip = true })
        client:TalentsReady("guid-1", "WARRIOR", "Bob", "", 3)
        client:TalentsReady("guid-2", "DRUID", "Ann", "Other", 1)
        assert.equal(icon(103), client:Icon("Bob-Realm"))
        assert.equal(icon(1101), client:Icon("Ann-Other"))
    end)

    it("leaves a player without points as they are", function()
        local client = NewClient({ tacoTip = true })
        client:Receive("Bob-Realm", "S:132")
        client:TalentsReady("guid-1", "WARRIOR", "Bob", "", nil)
        assert.equal(icon(132), client:Icon("Bob-Realm"))
    end)

    it("leaves the inspecting to the lib, and still sends its own message", function()
        local client = NewClient({ tacoTip = true, group = { bob() } })
        client:Wait(10)
        assert.same({}, client.inspects)
        assert.same({ "GUILD S:203", "PARTY S:203", "GUILD R", "PARTY R" }, client:TakeSent())
    end)
end)

describe("on WoW Forever", function()
    it("takes the player's icon from LibSpecialization", function()
        local client = NewClient({ client = "forever", specId = 70 })
        assert.equal(icon(5070), client:Icon("Me-Realm"))
        client.specId = 66
        client.lib.player()
        assert.equal(icon(5066), client:Icon("Me-Realm"))
    end)

    it("takes guild and group members' icons from LibSpecialization", function()
        local client = NewClient({ client = "forever" })
        client.lib.guild(65, "HEALER", "RANGED", "Bob")
        client.lib.group(73, "TANK", "MELEE", "Ann-Other")
        assert.equal(icon(5065), client:Icon("Bob-Realm"))
        assert.equal(icon(5073), client:Icon("Ann-Other"))
    end)

    it("asks the guild at login and when the roster allows it", function()
        local client = NewClient({ client = "forever" })
        assert.equal(1, client.guildRequests)
        client:Fire("GUILD_ROSTER_UPDATE", false)
        client:Fire("GUILD_ROSTER_UPDATE", true)
        assert.equal(2, client.guildRequests)
    end)

    it("sends none of the Classic Era messages and inspects nobody", function()
        local client = NewClient({ client = "forever", group = { bob() } })
        client:Wait(10)
        assert.is_nil(client.prefix)
        assert.same({}, client.inspects)
    end)
end)
