---@type string, table
local _, addon = ...
---@type Fader
local fader = addon.Core.Fader
---@type Registry
local registry = addon.Core.Registry

---@class MicroMenuModule
local M = registry:Add({
	Key = "MicroMenu",
	Title = "Micro Menu",
	Tooltip = "Fade the micro menu.",
	Default = true,
})

addon.Modules.MicroMenu = M

function M:Register()
	if not MicroMenu then
		return
	end

	fader:RegisterFade({
		Target = MicroMenu,
		IncludeChildren = true,
		ShouldFade = function()
			return registry:IsEnabled(M.Key)
		end,
	})

	-- Every loading screen comes back through here, and one scanner is enough: another would
	-- leave a frame and an OnPlay hook behind per zone change, all doing the same work.
	if MicroMenu.VuiStuckFixFrame then
		return
	end

	-- Blizzard's hover-icon animation on a child can be left stranded at alpha=0
	-- (shown but invisible) when MicroMenu was fading in from alpha=0 at hover time,
	-- causing Blizzard's animation to start from the wrong value. Scan every frame
	-- during fade-in so the fix applies within ~16ms of the texture getting stuck.

	-- The regions that scan looks at. Gathered once per fade rather than per frame: a fade is
	-- some sixty frames and the menu cannot gain a button midway through one, but it can
	-- between fades, so a stale list never outlives a single fade.
	local stuckCandidates = {}

	local function CollectStuckCandidates()
		wipe(stuckCandidates)

		for _, child in ipairs({ MicroMenu:GetChildren() }) do
			for _, region in ipairs({ child:GetRegions() }) do
				if region.GetAlpha and region.IsShown then
					stuckCandidates[#stuckCandidates + 1] = region
				end
			end
		end
	end

	local function FixStuckTextures()
		for i = 1, #stuckCandidates do
			local region = stuckCandidates[i]

			if region:GetAlpha() == 0 and region:IsShown() then
				region:SetAlpha(1)
			end
		end
	end

	local fixFrame = CreateFrame("Frame")
	MicroMenu.VuiStuckFixFrame = fixFrame

	MicroMenu.VuiFadeIn:HookScript("OnPlay", function()
		CollectStuckCandidates()

		fixFrame:SetScript("OnUpdate", function()
			FixStuckTextures()
			if not MicroMenu.VuiFadeIn:IsPlaying() then
				fixFrame:SetScript("OnUpdate", nil)
				FixStuckTextures()
			end
		end)
	end)
end
