local addonName, addon = ...
local verticalSpacing = 20
local checkboxesPerLine = 4
local checkboxWidth = 150
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
	},
}
local M = {}
addon.Config = M

local function CopyTable(src, dst)
	if type(dst) ~= "table" then
		dst = {}
	end

	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = CopyTable(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end

	return dst
end

local function CreateSettingCheckbox(panel, setting)
	local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	checkbox.Text:SetText(" " .. setting.Name)
	checkbox.Text:SetFontObject("GameFontNormal")
	checkbox:SetChecked(setting.Enabled())
	checkbox:HookScript("OnClick", function()
		setting.OnChanged(checkbox:GetChecked())
	end)

	checkbox:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(setting.Name, 1, 0.82, 0)
		GameTooltip:AddLine(setting.Tooltip, 1, 1, 1, true)
		GameTooltip:Show()
	end)

	checkbox:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	return checkbox
end

local function LayoutSettings(settings, panel, relativeTo, xOffset, yOffset)
	local x = xOffset
	local y = yOffset
	local lastCheckbox = nil

	for i, setting in ipairs(settings) do
		local checkbox = CreateSettingCheckbox(panel, setting)
		checkbox:SetPoint("TOPLEFT", relativeTo, "TOPLEFT", x, y)

		lastCheckbox = checkbox

		if i % checkboxesPerLine == 0 then
			y = y - (verticalSpacing * 2)
			x = xOffset
		else
			x = x + checkboxWidth
		end
	end

	return lastCheckbox
end

function CanOpenOptionsDuringCombat()
	if LE_EXPANSION_LEVEL_CURRENT == nil or LE_EXPANSION_MIDNIGHT == nil then
		return true
	end

	return LE_EXPANSION_LEVEL_CURRENT < LE_EXPANSION_MIDNIGHT
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
	MiniFaderDB = MiniFaderDB or {}
	db = CopyTable(dbDefaults, MiniFaderDB)

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

	local settings = {
		{
			Name = "Objective tracker",
			Tooltip = "Fade the objective/quests tracker, but show it inside instances.",
			Enabled = function()
				return db.Frames.ObjectiveTrackerFrame
			end,
			OnChanged = function(enabled)
				db.Frames.ObjectiveTrackerFrame = enabled
				fader:Refresh()
			end,
		},
		{
			Name = "Bags",
			Tooltip = "Fade the bags bar.",
			Enabled = function()
				return db.Frames.BagsBar
			end,
			OnChanged = function(enabled)
				db.Frames.BagsBar = enabled
				fader:Refresh()
			end,
		},
		{
			Name = "Micro Menu",
			Tooltip = "Fade the micro menu.",
			Enabled = function()
				return db.Frames.MicroMenu
			end,
			OnChanged = function(enabled)
				db.Frames.MicroMenu = enabled
				fader:Refresh()
			end,
		},
		{
			Name = "XP and Reputation",
			Tooltip = "Fade the XP and Reputation bars.",
			Enabled = function()
				return db.Frames.StatusTrackingBarManager
			end,
			OnChanged = function(enabled)
				db.Frames.StatusTrackingBarManager = enabled
				fader:Refresh()
			end,
		},
		{
			Name = "Raid manager",
			Tooltip = "Fade the raid manager flyout (left of screen flyout menu).",
			Enabled = function()
				return db.Frames.CompactRaidFrameManager
			end,
			OnChanged = function(enabled)
				db.Frames.CompactRaidFrameManager = enabled
				fader:Refresh()
			end,
		},
		{
			Name = "Buffs button",
			Tooltip = "Fade the collapse/expand buffs arrow button.",
			Enabled = function()
				return db.Frames.CollapseAndExpandButton
			end,
			OnChanged = function(enabled)
				db.Frames.CollapseAndExpandButton = enabled
				fader:Refresh()
			end,
		},
	}

	LayoutSettings(settings, panel, description, 0, -verticalSpacing * 2)

	SLASH_MINIFADER1 = "/minifader"
	SLASH_MINIFADER2 = "/mf"

	SlashCmdList.MINIFADER = function()
		if Settings then
			if not InCombatLockdown() or CanOpenOptionsDuringCombat() then
				Settings.OpenToCategory(category:GetID())
			end
		elseif InterfaceOptionsFrame_OpenToCategory then
			-- workaround the classic bug where the first call opens the Game interface
			-- and a second call is required
			InterfaceOptionsFrame_OpenToCategory(panel)
			InterfaceOptionsFrame_OpenToCategory(panel)
		end
	end
end
