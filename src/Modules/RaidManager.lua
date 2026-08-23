---@type string, table
local _, addon = ...
---@type Fader
local fader = addon.Core.Fader
---@type Registry
local registry = addon.Core.Registry

---@class RaidManagerModule
local M = registry:Add({
	Key = "CompactRaidFrameManager",
	Title = "Raid manager",
	Tooltip = "Fade the raid manager flyout (left of screen flyout menu).",
	Default = true,
})

addon.Modules.RaidManager = M

function M:Register()
	local target = CompactRaidFrameManager

	if not target then
		return
	end

	fader:RegisterFade({
		Target = target,
		ShouldFade = function()
			return registry:IsEnabled(M.Key)
		end,
	})
end
