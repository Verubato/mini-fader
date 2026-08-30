---@type string, table
local _, addon = ...
---@type Fader
local fader = addon.Core.Fader
---@type Registry
local registry = addon.Core.Registry

---@class StatusBarsModule
local M = registry:Add({
	Key = "StatusTrackingBarManager",
	Title = "XP and Rep",
	Tooltip = "Fade the XP and Reputation bars.",
	Default = true,
})

addon.Modules.StatusBars = M

function M:Register()
	local target = StatusTrackingBarManager

	if not target then
		return
	end

	fader:RegisterFade({
		Target = target,
		EnableMouse = true,
		ShouldFade = function()
			return registry:IsEnabled(M.Key)
		end,
	})
end
