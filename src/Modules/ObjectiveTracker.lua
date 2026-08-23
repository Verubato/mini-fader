---@type string, table
local _, addon = ...
---@type Fader
local fader = addon.Core.Fader
---@type Registry
local registry = addon.Core.Registry

---@class ObjectiveTrackerModule
local M = registry:Add({
	Key = "ObjectiveTrackerFrame",
	Title = "Objective tracker",
	Tooltip = "Fade the objective/quests tracker, but show it inside instances.",
	Default = true,
	Defaults = {
		Options = {
			ObjectiveTracker = {
				FadeWhen = {
					InPvE = false,
					InPvP = true,
				},
			},
		},
	},
})

addon.Modules.ObjectiveTracker = M

M.Options = {
	Title = "Objective Tracker Options",
	Settings = {
		{
			LabelText = "Fade in PvP",
			Tooltip = "Fade the objective/quests tracker in PvP instances.",
			GetValue = function()
				return registry:Vars().Options.ObjectiveTracker.FadeWhen.InPvP
			end,
			SetValue = function(enabled)
				registry:Vars().Options.ObjectiveTracker.FadeWhen.InPvP = enabled
				fader:Refresh()
				registry:Refresh()
			end,
		},
		{
			LabelText = "Fade in PvE",
			Tooltip = "Fade the objective/quests tracker in PvE instances.",
			GetValue = function()
				return registry:Vars().Options.ObjectiveTracker.FadeWhen.InPvE
			end,
			SetValue = function(enabled)
				registry:Vars().Options.ObjectiveTracker.FadeWhen.InPvE = enabled
				fader:Refresh()
				registry:Refresh()
			end,
		},
	},
}

function M:Register()
	local target = ObjectiveTrackerFrame

	if not target then
		return
	end

	fader:RegisterFade({
		Target = target,
		EnableMouse = true,
		ShouldFade = function()
			if not registry:IsEnabled(M.Key) then
				return false
			end

			local inInstance, instanceType = IsInInstance()

			if not inInstance then
				return true
			end

			if instanceType == "pvp" or instanceType == "arena" then
				return registry:Vars().Options.ObjectiveTracker.FadeWhen.InPvP
			end

			return registry:Vars().Options.ObjectiveTracker.FadeWhen.InPvE
		end,
		Events = { "PLAYER_ENTERING_WORLD" },
	})
end
