local addonName, addon = ...
---@type MiniFramework
local mini = addon.Framework
---@type Registry
local registry = addon.Core.Registry
local checkboxesPerLine = 4
local checkboxWidth = 150
local verticalSpacing = mini.VerticalSpacing

---@class Config
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

---The saved variable defaults: whether each module fades, plus anything a module keeps of
---its own.
local function Defaults()
	local defaults = { Frames = {} }
	local modules = registry:GetAll()

	for i = 1, #modules do
		local module = modules[i]

		if module.Key then
			defaults.Frames[module.Key] = module.Default
		end

		if module.Defaults then
			mini:CopyTable(module.Defaults, defaults)
		end
	end

	return defaults
end

---One checkbox per module that has a main setting, in the order the toc loaded them.
---@return CheckboxOptions[]
local function MainSettings(panel)
	local settings = {}
	local modules = registry:GetAll()

	for i = 1, #modules do
		local module = modules[i]

		if module.Key then
			settings[#settings + 1] = {
				Parent = panel,
				LabelText = module.Title,
				Tooltip = module.Tooltip,
				GetValue = function()
					return registry:IsEnabled(module.Key)
				end,
				SetValue = function(enabled)
					registry:SetEnabled(module.Key, enabled)
				end,
			}
		end
	end

	return settings
end

---A divider and a grid for each module that brings settings of its own, stacked under the
---main grid.
local function ModuleSections(panel, anchor)
	local modules = registry:GetAll()

	for i = 1, #modules do
		local options = modules[i].Options

		if options then
			local divider = mini:Divider({
				Parent = panel,
				Text = options.Title,
			})

			divider:SetPoint("LEFT", panel, "LEFT")
			divider:SetPoint("RIGHT", panel, "RIGHT")
			divider:SetPoint("TOP", anchor, "BOTTOM", 0, -verticalSpacing)

			-- the module has no panel to hand its checkboxes when it declares them
			for j = 1, #options.Settings do
				options.Settings[j].Parent = panel
			end

			-- a section with nothing in it still has to anchor the next one
			anchor = LayoutSettings(options.Settings, divider, 0, -verticalSpacing * 2) or divider
		end
	end
end

function M:Init()
	-- A styled button clashes with the stock Blizzard art around it in the settings screen.
	mini:SetCustomStyling(true, { Button = false })

	mini:GetSavedVars(Defaults())

	registry:Migrate()

	local panel = CreateFrame("Frame")
	panel.name = addonName

	local category = mini:AddCategory(panel)

	if not category then
		return
	end

	M.Panel = panel

	local header = mini:PanelHeader({
		Parent = panel,
		Description = "Simplify your UI.",
	})

	local mainDivider = mini:Divider({
		Parent = panel,
		Text = "Main",
	})

	mainDivider:SetPoint("LEFT", panel, "LEFT")
	mainDivider:SetPoint("RIGHT", panel, "RIGHT")
	mainDivider:SetPoint("TOP", header.Anchor, "BOTTOM", 0, -verticalSpacing)

	local anchor = LayoutSettings(MainSettings(panel), mainDivider, 0, -verticalSpacing * 2) or mainDivider

	ModuleSections(panel, anchor)

	-- /mf belongs to MiniFrames; everything here is spelled out for fading instead.
	mini:RegisterSlashCommand(category, panel, {
		"/fade",
		"/minifade",
		"/minifader",
		"/mfade",
		"/mfader",
	})
end
