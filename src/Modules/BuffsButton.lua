---@type string, table
local _, addon = ...
---@type Fader
local fader = addon.Core.Fader
---@type Registry
local registry = addon.Core.Registry

---@class BuffsButtonModule
local M = registry:Add({
	Key = "CollapseAndExpandButton",
	Title = "Buffs button",
	Tooltip = "Fade the collapse/expand buffs arrow button.",
	Default = false,
})

addon.Modules.BuffsButton = M

function M:Register()
	if not BuffFrame then
		return
	end

	local btn = BuffFrame.CollapseAndExpandButton

	if not btn then
		return
	end

	fader:RegisterFade({
		Target = btn,
		ShouldFade = function()
			return registry:IsEnabled(M.Key)
		end,
	})

	fader:RegisterFade({
		Target = btn,
		-- when hover mouse over BuffFrame, show the button
		MouseFrame = BuffFrame,
		ShouldFade = function()
			return registry:IsEnabled(M.Key)
		end,
	})
end
