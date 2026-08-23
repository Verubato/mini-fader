-- Drives the fader through a mocked client: what fades on login, what combat does to it,
-- and how a set of frames registered as one group behaves when the mouse arrives.

local fw = require("TestFramework")
local harness = require("AddonHarness")
local WowMock = require("WowMock")

---Loads the addon with the given frame settings already saved, then logs it in.
local function LoginWith(frames)
	local context = harness.Load("MiniFader")

	-- written before ADDON_LOADED, which is where the addon reads its saved variables
	_G.MiniFaderDB = { Frames = frames }

	harness.Login(context)

	return context
end

local function EnterCombat()
	WowMock.State.InCombat = true
	WowMock.FireEvent("PLAYER_REGEN_DISABLED")
end

local function LeaveCombat()
	WowMock.State.InCombat = false
	WowMock.FireEvent("PLAYER_REGEN_ENABLED")
end

fw.describe("MiniFader - fading", function()
	fw.it("fades the action bars out of combat and shows them in it", function()
		LoginWith({ ActionBars = true })

		fw.eq(MultiBarBottomLeft:GetAlpha(), 0, "bottom left bar alpha out of combat")

		EnterCombat()

		fw.eq(MultiBarBottomLeft:GetAlpha(), 1, "bottom left bar alpha in combat")
		fw.eq(MultiBarRight:GetAlpha(), 1, "side bar alpha in combat")

		-- the mock parents its buttons straight to UIParent, which the lookup has to refuse:
		-- fading it would take the whole interface with it
		fw.eq(UIParent:GetAlpha(), 1, "UIParent alpha")
	end)

	fw.it("finds a bar whose frame name has gone through its buttons", function()
		local context = harness.Load("MiniFader")

		_G.MiniFaderDB = { Frames = { ActionBars = true } }

		-- bar 1's frame is named differently per client version, so the mock has none of the
		-- names the addon knows and only its buttons can lead back to it
		local bar = CreateFrame("Frame", nil, UIParent)

		ActionButton1:SetParent(bar)

		harness.Login(context)

		fw.eq(bar:GetAlpha(), 0, "derived bar alpha")
	end)

	fw.it("keeps the action bars and player frame up inside an instance", function()
		LoginWith({ ActionBars = true, PlayerFrame = true })

		WowMock.State.InInstance = true
		WowMock.State.InstanceType = "party"
		WowMock.FireEvent("PLAYER_ENTERING_WORLD")

		fw.eq(MultiBarBottomLeft:GetAlpha(), 1, "bottom left bar alpha in an instance")
		fw.eq(PlayerFrame:GetAlpha(), 1, "player frame alpha in an instance")
	end)

	fw.it("leaves the action bars alone when the setting is off", function()
		LoginWith({ ActionBars = false })

		fw.eq(MultiBarBottomLeft:GetAlpha(), 1, "bottom left bar alpha")

		LeaveCombat()

		fw.eq(MultiBarBottomLeft:GetAlpha(), 1, "bottom left bar alpha after combat")
		fw.falsy(MultiBarBottomLeft.VuiFadeOut:IsPlaying(), "fade out playing")
	end)

	fw.it("eases the action bars away when combat ends rather than snapping them", function()
		LoginWith({ ActionBars = true })
		EnterCombat()
		LeaveCombat()

		fw.truthy(MultiBarBottomLeft.VuiFadeOut:IsPlaying(), "bottom left bar fading out")
		fw.eq(MultiBarBottomLeft:GetAlpha(), 1, "bottom left bar alpha while fading out")
	end)

	fw.it("stops a running fade-out when combat starts again", function()
		LoginWith({ ActionBars = true })
		EnterCombat()
		LeaveCombat()
		EnterCombat()

		fw.falsy(MultiBarBottomLeft.VuiFadeOut:IsPlaying(), "fade out playing")
		fw.eq(MultiBarBottomLeft:GetAlpha(), 1, "bottom left bar alpha")
	end)

	fw.it("fades the player frame out of combat", function()
		LoginWith({ PlayerFrame = true })

		fw.eq(PlayerFrame:GetAlpha(), 0, "player frame alpha out of combat")

		EnterCombat()

		fw.eq(PlayerFrame:GetAlpha(), 1, "player frame alpha in combat")
	end)

	fw.it("brings back every frame in a group when one of them is hovered", function()
		local context = LoginWith({})
		local fader = context.Addon.Fader

		local first = CreateFrame("Frame", nil, UIParent)
		local second = CreateFrame("Frame", nil, UIParent)

		first:EnableMouse(true)

		fader:RegisterFade({
			Targets = { first, second },
			ShouldFade = function()
				return true
			end,
		})

		fw.eq(second:GetAlpha(), 0, "second frame alpha")

		first:GetScript("OnEnter")(first)

		fw.truthy(second.VuiFadeIn:IsPlaying(), "second frame fading in")
	end)

	fw.it("counts the fade-out grace period down once per group", function()
		local context = LoginWith({})
		local fader = context.Addon.Fader

		local first = CreateFrame("Frame", nil, UIParent)
		local second = CreateFrame("Frame", nil, UIParent)

		first:EnableMouse(true)
		second:EnableMouse(true)

		fader:RegisterFade({
			Targets = { first, second },
			ShouldFade = function()
				return true
			end,
		})

		local group = first.VuiFadeGroup

		fw.eq(group, second.VuiFadeGroup, "shared group")

		first:GetScript("OnEnter")(first)

		fw.is_nil(group.FadeOutTimer, "timer while hovered")

		first:GetScript("OnLeave")(first)
		second:GetScript("OnLeave")(second)

		fw.not_nil(group.FadeOutTimer, "timer after leaving")

		-- the mock never finishes an animation, so stand in for a completed fade-in
		first:SetAlpha(1)

		-- combat and loading screens refresh every target, but a group already counting
		-- down keeps its grace period rather than being faded on the spot
		WowMock.FireEvent("PLAYER_REGEN_ENABLED")

		fw.falsy(first.VuiFadeOut:IsPlaying(), "fade out playing")
	end)

	fw.it("picks up a frame that only joins its group later", function()
		local context = LoginWith({})
		local fader = context.Addon.Fader

		local first = CreateFrame("Frame", nil, UIParent)
		local late = CreateFrame("Frame", nil, UIParent)

		first:EnableMouse(true)

		local function Register(...)
			fader:RegisterFade({
				Targets = { ... },
				ShouldFade = function()
					return true
				end,
			})
		end

		Register(first)
		Register(first, late)

		fw.eq(late:GetAlpha(), 0, "late frame alpha")

		first:GetScript("OnEnter")(first)

		fw.truthy(late.VuiFadeIn:IsPlaying(), "late frame fading in")
	end)

	fw.it("lets one hover frame wake more than one group", function()
		local context = LoginWith({})
		local fader = context.Addon.Fader

		local hover = CreateFrame("Frame", nil, UIParent)

		hover:EnableMouse(true)

		for _ = 1, 2 do
			fader:RegisterFade({
				Target = CreateFrame("Frame", nil, UIParent),
				MouseFrame = hover,
				ShouldFade = function()
					return true
				end,
			})
		end

		local groups = 0

		for _ in pairs(hover.VuiFocusGroups) do
			groups = groups + 1
		end

		fw.eq(groups, 2, "groups the hover frame wakes")
	end)

	fw.it("takes an extra hover frame for an already registered target", function()
		local context = LoginWith({})
		local fader = context.Addon.Fader

		local target = CreateFrame("Frame", nil, UIParent)
		local hover = CreateFrame("Frame", nil, UIParent)

		hover:EnableMouse(true)

		local options = {
			Target = target,
			ShouldFade = function()
				return true
			end,
		}

		fader:RegisterFade(options)

		options.MouseFrame = hover
		fader:RegisterFade(options)

		hover:GetScript("OnEnter")(hover)

		fw.truthy(target.VuiFadeIn:IsPlaying(), "target fading in")
	end)
end)
