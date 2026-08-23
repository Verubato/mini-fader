---@type string, table
local _, addon = ...
---@type Fader
local fader = addon.Core.Fader
---@type Registry
local registry = addon.Core.Registry

---@class ActionBarsModule
local M = registry:Add({
	Key = "ActionBars",
	Title = "Action bars",
	Tooltip = "Fade the action bars while out of combat and outside instances.",
	Default = false,
})

addon.Modules.ActionBars = M

local combatAndZoneEvents = { "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD" }
-- Every bar the default UI can show, by frame name and by the first of its buttons. They fade
-- as one group, otherwise hovering the bottom bar would leave the one stacked on top of it
-- invisible. Blizzard renames these between expansions - bar 1 was MainMenuBar before 12.0 -
-- so a bar the client has no frame named for is found through its buttons instead.
local actionBars = {
	{ Frame = "MainActionBar", Button = "ActionButton1" },
	{ Frame = "MultiBarBottomLeft", Button = "MultiBarBottomLeftButton1" },
	{ Frame = "MultiBarBottomRight", Button = "MultiBarBottomRightButton1" },
	{ Frame = "MultiBarRight", Button = "MultiBarRightButton1" },
	{ Frame = "MultiBarLeft", Button = "MultiBarLeftButton1" },
	{ Frame = "MultiBar5", Button = "MultiBar5Button1" },
	{ Frame = "MultiBar6", Button = "MultiBar6Button1" },
	{ Frame = "MultiBar7", Button = "MultiBar7Button1" },
	{ Frame = "StanceBar", Button = "StanceButton1" },
	{ Frame = "PetActionBar", Button = "PetActionButton1" },
	{ Frame = "PossessActionBar", Button = "PossessButton1" },
}

local function ActionBarFrames()
	local bars = {}
	local seen = {}

	for _, bar in ipairs(actionBars) do
		local frame = _G[bar.Frame]

		if not frame then
			local button = _G[bar.Button]
			frame = button and button:GetParent()
		end

		-- UIParent would take the whole interface down with it
		if frame and frame ~= UIParent and not seen[frame] then
			seen[frame] = true
			bars[#bars + 1] = frame
		end
	end

	return bars
end

function M:Register()
	local bars = ActionBarFrames()

	if #bars == 0 then
		return
	end

	fader:RegisterFade({
		Targets = bars,
		-- the buttons are what the mouse actually touches, and a bar that isn't full holds
		-- them a level further down, so go two deep rather than one
		IncludeChildren = 2,
		ShouldFade = function()
			return registry:IsEnabled(M.Key) and not InCombatLockdown() and not IsInInstance()
		end,
		Events = combatAndZoneEvents,
	})
end
