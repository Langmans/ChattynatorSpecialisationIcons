# Chattynator Specialisation Icons

[![Game Version](https://img.shields.io/badge/WoW-12.0.0-blue.svg)](https://worldofwarcraft.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

**Chattynator Specialisation Icons** is a lightweight plugin for the **Chattynator** addon that injects player specialization icons (e.g., Protection, Havoc, Restoration) directly into your chat messages.

## ✨ Features

* **Visual Spec Identification:** Automatically displays icons for players in your Guild or Group.
* **Dynamic Injection:** Uses the Chattynator API to modify text without breaking player links or chat functionality.
* **Performance Focused:** Features a metatable-based caching system for icons to ensure minimal CPU usage.
* **Real-time Updates:** Synchronizes with `LibSpecialization` to reflect spec changes immediately.

## 🛠 Requirements

This addon is a module and requires the following to function:
* **[Chattynator](https://www.curseforge.com/wow/addons/chattynator)** (Core Addon)

### Optional Dependencies
* **_DebugLog**: Enables technical logging via `DLAPI`.
* **LibSpecialization**: Handled internally, but supports standalone versions.

## 📦 Installation

1.  Download the latest version.
2.  Extract the files into your WoW AddOns folder:
    `_retail_/Interface/AddOns/ChattynatorSpecialisationIcons`
3.  Ensure the addon is enabled in the Character Selection screen.

## ⌨️ How it Works

The addon hooks into Chattynator's modifier API. When a message is received:
1.  It checks the sender's name against a known database of specialization IDs collected from `LibSpecialization`.
2.  It converts the spec ID into a texture markup string.
3.  It modifies the chat string to place the icon immediately following the player's name link.

## 📜 Technical Info

* **Author:** Langmans
* **Version:** 0.0.1
* **Interface Compatibility:** 120000, 120001 (Midnight)

---

*Developed for the WoW community. Please report any issues via the GitHub repository.*