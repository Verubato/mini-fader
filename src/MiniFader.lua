local _, addon = ...
---@type MiniFramework
local mini = addon.Framework
---@type Fader
local fader = addon.Core.Fader
---@type Registry
local registry = addon.Core.Registry
local eventsFrame

local function OnEnteringWorld()
	registry:Register()
	registry:Refresh()

	-- most notably the chat background needs to be refreshed. Animated, because a zone change
	-- lands here too and a frame that starts fading then should ease away rather than blink out.
	fader:Refresh(true)
end

local function OnAddonLoaded()
	-- the defaults have to be merged before the registry hands the saved variables round
	addon.Config:Init()

	registry:Init()

	-- wait a bit later for frames to be created
	eventsFrame = CreateFrame("Frame")
	eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventsFrame:SetScript("OnEvent", OnEnteringWorld)
end

mini:WaitForAddonLoad(OnAddonLoaded)
