---@type string, table
local _, addon = ...
---@type Fader
local fader = addon.Core.Fader
---@type Registry
local registry = addon.Core.Registry

---@class PlayerFrameModule
local M = registry:Add({
	Key = "PlayerFrame",
	Title = "Player frame",
	Tooltip = "Fade the player's health and power bars while out of combat and outside instances.",
	Default = false,
})

addon.Modules.PlayerFrame = M

local combatAndZoneEvents = { "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD" }

function M:Register()
	local target = PlayerFrame

	if not target then
		return
	end

	fader:RegisterFade({
		Target = target,
		ShouldFade = function()
			return registry:IsEnabled(M.Key) and not InCombatLockdown() and not IsInInstance()
		end,
		Events = combatAndZoneEvents,
	})
end
