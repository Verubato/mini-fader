---@type string, table
local _, addon = ...
---@type Fader
local fader = addon.Core.Fader
---@type Registry
local registry = addon.Core.Registry

---@class BagsModule
local M = registry:Add({
	Key = "BagsBar",
	Title = "Bags",
	Tooltip = "Fade the bags bar.",
	Default = true,
})

addon.Modules.Bags = M

function M:Register()
	if not BagsBar then
		return
	end

	fader:RegisterFade({
		Target = BagsBar,
		IncludeChildren = true,
		ShouldFade = function()
			return registry:IsEnabled(M.Key)
		end,
	})
end
