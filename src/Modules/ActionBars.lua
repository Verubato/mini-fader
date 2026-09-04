---@type string, table
local _, addon = ...
---@type Fader
local fader = addon.Core.Fader
---@type Registry
local registry = addon.Core.Registry

local combatAndZoneEvents = { "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD" }
-- Blizzard renames a bar's frame between expansions, so one the client has no name for is
-- found through its buttons instead.
-- Id is the settings key rather than Frame, so a rename can't reset a player's saved choice.
local actionBars = {
	{ Frame = "MainActionBar", Button = "ActionButton1", Label = "Action bar 1", Id = "Bar1" },
	{ Frame = "MultiBarBottomLeft", Button = "MultiBarBottomLeftButton1", Label = "Action bar 2", Id = "Bar2" },
	{ Frame = "MultiBarBottomRight", Button = "MultiBarBottomRightButton1", Label = "Action bar 3", Id = "Bar3" },
	{ Frame = "MultiBarRight", Button = "MultiBarRightButton1", Label = "Action bar 4", Id = "Bar4" },
	{ Frame = "MultiBarLeft", Button = "MultiBarLeftButton1", Label = "Action bar 5", Id = "Bar5" },
	{ Frame = "MultiBar5", Button = "MultiBar5Button1", Label = "Action bar 6", Id = "Bar6" },
	{ Frame = "MultiBar6", Button = "MultiBar6Button1", Label = "Action bar 7", Id = "Bar7" },
	{ Frame = "MultiBar7", Button = "MultiBar7Button1", Label = "Action bar 8", Id = "Bar8" },
	{ Frame = "StanceBar", Button = "StanceButton1", Label = "Stance bar", Id = "Stance" },
	{ Frame = "PetActionBar", Button = "PetActionButton1", Label = "Pet bar", Id = "Pet" },
	{ Frame = "PossessActionBar", Button = "PossessButton1", Label = "Possess bar", Id = "Possess" },
}
local barDefaults = {}
local barSettings = {}

for _, bar in ipairs(actionBars) do
	local id = bar.Id

	barDefaults[id] = false
	barSettings[#barSettings + 1] = {
		LabelText = bar.Label,
		Tooltip = "Fade " .. bar.Label:lower() .. " while out of combat and outside instances.",
		GetValue = function()
			return registry:Vars().Options.ActionBars[id]
		end,
		SetValue = function(enabled)
			registry:Vars().Options.ActionBars[id] = enabled
			fader:Refresh()
			registry:Refresh()
		end,
	}
end

---@class ActionBarsModule
local M = registry:Add({
	Defaults = {
		Options = {
			ActionBars = barDefaults,
		},
	},
})

addon.Modules.ActionBars = M

M.Options = {
	Title = "Action Bars",
	Settings = barSettings,
}

---The frame the client built for a bar, if it has one.
local function BarFrame(bar)
	local frame = _G[bar.Frame]

	if not frame then
		local button = _G[bar.Button]
		frame = button and button:GetParent()
	end

	return frame
end

function M:Register()
	local seen = {}

	for _, bar in ipairs(actionBars) do
		local frame = BarFrame(bar)
		local id = bar.Id

		-- UIParent would take the whole interface down with it
		if frame and frame ~= UIParent and not seen[frame] then
			seen[frame] = true

			fader:RegisterFade({
				Target = frame,
				-- the buttons are what the mouse actually touches, and a bar that isn't full
				-- holds them a level further down, so go two deep rather than one
				IncludeChildren = 2,
				ShouldFade = function()
					return registry:Vars().Options.ActionBars[id] and not InCombatLockdown() and not IsInInstance()
				end,
				Events = combatAndZoneEvents,
			})
		end
	end
end

---One checkbox became one per bar, so carry what the player had onto all of them.
function M:Migrate()
	local vars = registry:Vars()
	local wasEnabled = vars.Frames.ActionBars

	if wasEnabled == nil then
		return
	end

	for _, bar in ipairs(actionBars) do
		vars.Options.ActionBars[bar.Id] = wasEnabled
	end

	vars.Frames.ActionBars = nil
end
