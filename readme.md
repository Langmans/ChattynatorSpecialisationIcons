# Chattynator Specialisation Icons

[![Release](https://img.shields.io/github/v/release/Langmans/ChattynatorSpecialisationIcons?include_prereleases)](https://github.com/Langmans/ChattynatorSpecialisationIcons/releases)
[![Game Version](https://img.shields.io/badge/WoW-12.0.0-blue.svg)](https://worldofwarcraft.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

**Chattynator Specialisation Icons** is a lightweight plugin for the **Chattynator** addon that injects player specialization icons (e.g., Protection, Havoc, Restoration) directly into your chat messages.

## ✨ Features

* **Visual Spec Identification:** Automatically displays icons for players in your Guild or Group (if they also have LibSpecialisation in one of their addons).
* **Dynamic Injection:** Uses the Chattynator API to modify text without breaking player links or chat functionality.
* **Performance Focused:** Features a metatable-based caching system for icons to ensure minimal CPU usage.
* **Real-time Updates:** Synchronizes with `LibSpecialization` from other people to reflect spec changes immediately.

## 🛠 Requirements

This addon is a module and requires the following to function:
* **[Chattynator](https://www.curseforge.com/wow/addons/chattynator)** (Core Addon)

On Retail and WoW Forever, other raid/party members or guild members will need at least [one addon that uses LibSpecialisation](https://www.curseforge.com/wow/addons/libspecialization/relations/dependents), such as BigWigs or DBM. If you get messages from people without an icon, it means you haven't received their specialization info yet or they don't have any addon that has LibSpecialization embedded.

### Classic Era

Classic Era has talent trees instead of specialisations, and LibSpecialization does not run there. A player's icon is the icon of their talent tree with the most points. It comes from:

* your own talents;
* guild and group members who run this addon too;
* [TacoTip](https://www.curseforge.com/wow/addons/tacotip-gearscore-talents), when you have it: its LibClassicInspector shares talents with every TacoTip user and inspects the players around you;
* without TacoTip: an inspect of group members within range, one at a time, out of combat.

Players in `/say`, whispers or trade who run none of these get no icon.

### Optional Dependencies
* **_DebugLog**: Enables technical logging via `DLAPI`.
* **LibSpecialization**: Handled internally, but supports standalone versions.
* **TacoTip**: More icons on Classic Era (see above).

## 📦 Installation

1.  Download the latest version.
2.  Extract the files into your WoW AddOns folder, e.g.:
    `_retail_/Interface/AddOns/ChattynatorSpecialisationIcons` (or `_classic_era_`, `_forever_`)
3.  Ensure the addon is enabled in the Character Selection screen.

## ⌨️ How it Works (technical details)

The addon hooks into Chattynator's modifier API. When a message is received:
1.  It checks the sender's name ("Name-Realm") against the icons collected so far.
2.  It places the icon's texture markup inside the player's name link, after the opening bracket.

`ChattynatorSpecialisationIcons.lua` keeps one icon file ID per player and does the chat part; on Retail and Forever it fills them from `LibSpecialization` (spec ID to icon via `GetSpecializationInfoForSpecID`).

`Era.lua` runs only where LibSpecialization does not:

* **Own tree:** `C_SpecializationInfo.GetSpecializationInfo(i)` per tree; the most points win, the first of equals. Read again on `PLAYER_TALENT_UPDATE`, `CHARACTER_POINTS_CHANGED` and `ACTIVE_TALENT_GROUP_CHANGED`.
* **Addon message** (prefix `ChattySpecIcon`, guild and group): `S:<icon file ID>` is a player's icon, `S:` none, `R` asks everyone for theirs. At login the addon sends its state and a request to guild and group, on joining a group to the group. Requests on one channel get one answer after 3 seconds. The icon file ID travels as is, so the receiver needs no lookup.
* **TacoTip's LibClassicInspector**, when loaded: on its `TALENTS_READY` the tree index from `GetSpecialization(guid)` becomes the icon via `GetSpecializationInfoForClassID`. The addon's own inspecting is then off; the lib inspects already.
* **Inspect** otherwise: every 2 seconds, out of combat and while Blizzard's inspect window is closed, the first group member without an icon who is in inspect range gets a `NotifyInspect`. On `INSPECT_READY` their top tree comes from `GetSpecializationInfo(i, true)`. Each member is inspected once per session; an answer that does not come within 5 seconds is given up and tried again later.

## 🧪 Development

Tests and checks run with Lua 5.1 from the repository root:

```
lua tests/check.lua           StyLua, WoW Lua LS, then the tests with coverage
lua tests/check.lua test      the tests only
lua tests/check.lua format    formats all Lua with StyLua
```

`tests/setup-lua.ps1` installs Lua, LuaRocks, the test rocks and StyLua into `.lua\` on Windows. `tests/wow.lua` simulates the client, Chattynator, LibSpecialization and LibClassicInspector. Every line of the addon must run in a test, and the WoW Lua LS must resolve every symbol's type. CI (`.github/workflows/ci.yml`) runs the same on every push.

---

*Developed for the WoW community. Please report any issues via the GitHub repository.*