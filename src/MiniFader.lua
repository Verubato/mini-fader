local addonName, addon = ...
local frame
---@type Config
local db
local fader = addon.Fader

local function FadeBuffsButton()
	if not BuffFrame then
		return
	end

	local btn = BuffFrame.CollapseAndExpandButton

	if not btn then
		return
	end

	fader:RegisterFade({
		Target = btn,
		ShouldFade = function()
			return db.Frames.CollapseAndExpandButton
		end,
	})

	fader:RegisterFade({
		Target = btn,
		-- when hover mouse over BuffFrame, show the button
		MouseFrame = BuffFrame,
		ShouldFade = function()
			return db.Frames.CollapseAndExpandButton
		end,
	})
end

local function FadeBags()
	if not BagsBar then
		return
	end

	fader:RegisterFade({
		Target = BagsBar,
		IncludeChildren = true,
		ShouldFade = function()
			return db.Frames.BagsBar
		end,
	})
end

local function FadeMicroMenu()
	if not MicroMenu then
		return
	end

	fader:RegisterFade({
		Target = MicroMenu,
		IncludeChildren = true,
		EnableMouse = false,
		ShouldFade = function()
			return db.Frames.MicroMenu
		end,
	})
end

local function FadeQuests()
	local target = ObjectiveTrackerFrame

	if not target then
		return
	end

	fader:RegisterFade({
		Target = target,
		ShouldFade = function()
			if not db.Frames.ObjectiveTrackerFrame then
				return false
			end

			-- fade when inside an not in an instance, or in an arena
			local inInstance, instanceType = IsInInstance()
			return not inInstance or instanceType == "arena"
		end,
		Events = { "PLAYER_ENTERING_WORLD" },
	})
end

local function FadeRaidFrameManager()
	local target = CompactRaidFrameManager

	if not target then
		return
	end

	fader:RegisterFade({
		Target = target,
		ShouldFade = function()
			return db.Frames.CompactRaidFrameManager
		end,
	})
end

local function FadeXpAndRep()
	local target = StatusTrackingBarManager

	if not target then
		return
	end

	fader:RegisterFade({
		Target = target,
		ShouldFade = function()
			return db.Frames.StatusTrackingBarManager
		end,
	})
end

local function Init()
	if not db or not db.Frames then
		return
	end

	FadeBuffsButton()
	FadeBags()
	FadeMicroMenu()
	FadeQuests()
	FadeRaidFrameManager()
	FadeXpAndRep()
end

local function OnEnteringWorld()
	Init()
end

local function OnAddonLoaded(_, _, name)
	if name ~= addonName then
		return
	end

	addon.Config:Init()

	db = MiniFaderDB or {}

	frame:UnregisterEvent("ADDON_LOADED")

	-- wait a bit later for frames to be created
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:SetScript("OnEvent", OnEnteringWorld)
end

frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", OnAddonLoaded)
