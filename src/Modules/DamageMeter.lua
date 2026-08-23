---@type string, table
local _, addon = ...
---@type Fader
local fader = addon.Core.Fader
---@type Registry
local registry = addon.Core.Registry

---@class DamageMeterModule
local M = registry:Add({
	Key = "DamageMeter",
	Title = "Damage meter",
	Tooltip = "Fade the Blizzard damage meter.",
	Default = false,
})

addon.Modules.DamageMeter = M

function M:Register()
	local window = 1
	local frame = _G["DamageMeterSessionWindow" .. window]

	while frame do
		fader:RegisterFade({
			Target = frame,
			ShouldFade = function()
				return registry:IsEnabled(M.Key) and not IsInInstance()
			end,
		})

		window = window + 1
		frame = _G["DamageMeterSessionWindow" .. window]
	end
end
