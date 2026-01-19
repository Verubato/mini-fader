local addonName, addon = ...
---@type MiniFramework
local mini = addon.Framework
local checkboxesPerLine = 4
local checkboxWidth = 150
local verticalSpacing = mini.VerticalSpacing
local fader = addon.Fader
---@type Config
local db
---@class Config
local dbDefaults = {
	Frames = {
		BagsBar = true,
		MicroMenu = true,
		ObjectiveTrackerFrame = true,
		CompactRaidFrameManager = true,
		StatusTrackingBarManager = true,
		CollapseAndExpandButton = false,
		Chat = false,
	},
}
local M = {}
addon.Config = M

local function LayoutSettings(settings, relativeTo, xOffset, yOffset)
	local x = xOffset
	local y = yOffset
	local bottomLeftCheckbox = nil
	local isNewRow = true

	for i, setting in ipairs(settings) do
		local checkbox = mini:Checkbox(setting)
		checkbox:SetPoint("TOPLEFT", relativeTo, "TOPLEFT", x, y)

		if isNewRow then
			bottomLeftCheckbox = checkbox
		end

		if i % checkboxesPerLine == 0 then
			y = y - (verticalSpacing * 2)
			x = xOffset

			isNewRow = true
		else
			x = x + checkboxWidth

			isNewRow = false
		end
	end

	return bottomLeftCheckbox
end

local function AddCategory(panel)
	if Settings then
		local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
		Settings.RegisterAddOnCategory(category)

		return category
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)

		return panel
	end

	return nil
end

function M:Init()
	db = mini:GetSavedVars(dbDefaults)

	local panel = CreateFrame("Frame")
	panel.name = addonName

	local category = AddCategory(panel)

	if not category then
		return
	end

	local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 0, -verticalSpacing)
	title:SetText(string.format("%s - %s", addonName, version))

	local description = panel:CreateFontString(nil, "ARTWORK", "GameFontWhite")
	description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	description:SetText("Simplify your UI.")

	---@type CheckboxOptions[]
	local settings = {
		{
			Parent = panel,
			LabelText = "Objective tracker",
			Tooltip = "Fade the objective/quests tracker, but show it inside instances.",
			GetValue = function()
				return db.Frames.ObjectiveTrackerFrame
			end,
			SetValue = function(enabled)
				db.Frames.ObjectiveTrackerFrame = enabled
				fader:Refresh()
				addon:Refresh()
			end,
		},
		{
			Parent = panel,
			LabelText = "Bags",
			Tooltip = "Fade the bags bar.",
			GetValue = function()
				return db.Frames.BagsBar
			end,
			SetValue = function(enabled)
				db.Frames.BagsBar = enabled
				fader:Refresh()
				addon:Refresh()
			end,
		},
		{
			Parent = panel,
			LabelText = "Micro Menu",
			Tooltip = "Fade the micro menu.",
			GetValue = function()
				return db.Frames.MicroMenu
			end,
			SetValue = function(enabled)
				db.Frames.MicroMenu = enabled
				fader:Refresh()
				addon:Refresh()
			end,
		},
		{
			Parent = panel,
			LabelText = "Chat",
			Tooltip = "Fade the chat tabs.",
			GetValue = function()
				return db.Frames.Chat
			end,
			SetValue = function(enabled)
				db.Frames.Chat = enabled
				fader:Refresh()
				addon:Refresh()
			end,
		},
		{
			Parent = panel,
			LabelText = "XP and Reputation",
			Tooltip = "Fade the XP and Reputation bars.",
			GetValue = function()
				return db.Frames.StatusTrackingBarManager
			end,
			SetValue = function(enabled)
				db.Frames.StatusTrackingBarManager = enabled
				fader:Refresh()
				addon:Refresh()
			end,
		},
		{
			Parent = panel,
			LabelText = "Raid manager",
			Tooltip = "Fade the raid manager flyout (left of screen flyout menu).",
			GetValue = function()
				return db.Frames.CompactRaidFrameManager
			end,
			SetValue = function(enabled)
				db.Frames.CompactRaidFrameManager = enabled
				fader:Refresh()
				addon:Refresh()
			end,
		},
		{
			Parent = panel,
			LabelText = "Buffs button",
			Tooltip = "Fade the collapse/expand buffs arrow button.",
			GetValue = function()
				return db.Frames.CollapseAndExpandButton
			end,
			SetValue = function(enabled)
				db.Frames.CollapseAndExpandButton = enabled
				fader:Refresh()
				addon:Refresh()
			end,
		},
	}

	LayoutSettings(settings, description, 0, -verticalSpacing * 2)

	mini:RegisterSlashCommand(category, panel, {
		"/minifader",
		"/mf",
	})
end
