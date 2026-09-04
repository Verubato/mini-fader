-- Drives the fader through a mocked client: what fades on login, what combat does to it,
-- and how a set of frames registered as one group behaves when the mouse arrives.

local fw = require("TestFramework")
local harness = require("AddonHarness")
local WowMock = require("WowMock")

---Overrides one or more globals for the duration of fn, restoring them even if fn raises,
---so one failing assertion can't leave a later test running against a patched global.
---@param overrides table<string, any>
---@param fn fun()
local function WithGlobals(overrides, fn)
	local reals = {}

	for name, value in pairs(overrides) do
		reals[name] = _G[name]
		_G[name] = value
	end

	local ok, err = pcall(fn)

	for name, value in pairs(reals) do
		_G[name] = value
	end

	if not ok then
		error(err, 0)
	end
end

-- the settings ids of the bars the mock builds a frame for
local mockedBars = { "Bar2", "Bar3", "Bar4", "Bar5", "Stance", "Pet" }

---Loads the addon with the given frame and option settings already saved, then logs it in.
local function LoginWith(frames, options)
	local context = harness.Load("MiniFader")

	-- written before ADDON_LOADED, which is where the addon reads its saved variables
	_G.MiniFaderDB = { Frames = frames, Options = options }

	harness.Login(context)

	return context
end

---The action bar settings, with every bar the mock builds set to the same value.
local function AllBars(enabled)
	local bars = {}

	for _, name in ipairs(mockedBars) do
		bars[name] = enabled
	end

	return { ActionBars = bars }
end

---The panel checkbox with the given label.
local function FindCheckbox(panel, labelText)
	for _, control in ipairs(panel.MiniControls) do
		if control.Text and control.Text:GetText() == labelText then
			return control
		end
	end
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
		LoginWith({}, AllBars(true))

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

		_G.MiniFaderDB = { Options = { ActionBars = { Bar1 = true } } }

		-- bar 1's frame is named differently per client version, so the mock has none of the
		-- names the addon knows and only its buttons can lead back to it
		local bar = CreateFrame("Frame", nil, UIParent)

		ActionButton1:SetParent(bar)

		harness.Login(context)

		fw.eq(bar:GetAlpha(), 0, "derived bar alpha")
	end)

	fw.it("keeps the action bars and player frame up inside an instance", function()
		LoginWith({ PlayerFrame = true }, AllBars(true))

		WowMock.State.InInstance = true
		WowMock.State.InstanceType = "party"
		WowMock.FireEvent("PLAYER_ENTERING_WORLD")

		fw.eq(MultiBarBottomLeft:GetAlpha(), 1, "bottom left bar alpha in an instance")
		fw.eq(PlayerFrame:GetAlpha(), 1, "player frame alpha in an instance")
	end)

	fw.it("leaves the action bars alone when the setting is off", function()
		LoginWith({}, AllBars(false))

		fw.eq(MultiBarBottomLeft:GetAlpha(), 1, "bottom left bar alpha")

		LeaveCombat()

		fw.eq(MultiBarBottomLeft:GetAlpha(), 1, "bottom left bar alpha after combat")
		fw.falsy(MultiBarBottomLeft.VuiFadeOut:IsPlaying(), "fade out playing")
	end)

	fw.it("eases the action bars away when combat ends rather than snapping them", function()
		LoginWith({}, AllBars(true))
		EnterCombat()
		LeaveCombat()

		fw.truthy(MultiBarBottomLeft.VuiFadeOut:IsPlaying(), "bottom left bar fading out")
		fw.eq(MultiBarBottomLeft:GetAlpha(), 1, "bottom left bar alpha while fading out")
	end)

	fw.it("stops a running fade-out when combat starts again", function()
		LoginWith({}, AllBars(true))
		EnterCombat()
		LeaveCombat()
		EnterCombat()

		fw.falsy(MultiBarBottomLeft.VuiFadeOut:IsPlaying(), "fade out playing")
		fw.eq(MultiBarBottomLeft:GetAlpha(), 1, "bottom left bar alpha")
	end)

	fw.it("fades only the action bars that are switched on", function()
		LoginWith({}, { ActionBars = { Bar2 = true, Bar4 = false } })

		fw.eq(MultiBarBottomLeft:GetAlpha(), 0, "bottom left bar alpha")
		fw.eq(MultiBarRight:GetAlpha(), 1, "side bar alpha")
		fw.not_nil(MultiBarRight.VuiFadeGroup, "side bar registered with a fade group")
	end)

	fw.it("brings back another enabled bar when one of them is hovered", function()
		local context = harness.Load("MiniFader")

		_G.MiniFaderDB = { Options = { ActionBars = { Bar2 = true, Bar4 = true } } }

		-- the client's bars take mouse input, the mock's frames don't until they're told to
		MultiBarBottomLeft:EnableMouse(true)

		harness.Login(context)

		fw.eq(MultiBarRight:GetAlpha(), 0, "side bar alpha before the hover")

		MultiBarBottomLeft:GetScript("OnEnter")(MultiBarBottomLeft)

		fw.truthy(MultiBarRight.VuiFadeIn:IsPlaying(), "side bar fading in")
	end)

	fw.it("carries the old single action bars setting onto every bar", function()
		LoginWith({ ActionBars = true })

		fw.eq(MultiBarBottomLeft:GetAlpha(), 0, "bottom left bar alpha")
		fw.eq(PetActionBar:GetAlpha(), 0, "pet bar alpha")
		fw.is_nil(_G.MiniFaderDB.Frames.ActionBars, "the setting the bars were migrated off")
	end)

	fw.it("shows a migrated action bar setting as checked on the options panel", function()
		local context = LoginWith({ ActionBars = true })

		local checkbox = FindCheckbox(context.Addon.Config.Panel, "Action bar 2")

		fw.truthy(checkbox, "action bar checkbox found")
		fw.truthy(checkbox:GetChecked(), "action bar checkbox checked")
	end)

	fw.it("fades the bar its checkbox names and leaves another bar alone", function()
		local context = LoginWith({}, AllBars(false))

		local checkbox = FindCheckbox(context.Addon.Config.Panel, "Action bar 4")

		checkbox:Click()

		fw.eq(MultiBarRight:GetAlpha(), 0, "action bar 4 alpha")
		fw.eq(MultiBarBottomLeft:GetAlpha(), 1, "other bar alpha")
	end)

	fw.it("fades an action bar out again once a mouseover of it ends", function()
		local context = harness.Load("MiniFader")

		_G.MiniFaderDB = { Options = { ActionBars = { Bar2 = true, Bar4 = false } } }

		MultiBarBottomLeft:EnableMouse(true)

		harness.Login(context)

		MultiBarBottomLeft:GetScript("OnEnter")(MultiBarBottomLeft)

		-- the mock never finishes an animation, so stand in for the fade-in having completed
		MultiBarBottomLeft.VuiFadeIn:Stop()
		MultiBarBottomLeft:SetAlpha(1)

		MultiBarBottomLeft:GetScript("OnLeave")(MultiBarBottomLeft)

		WowMock.AdvanceTime(4)
		WowMock.RunTimers()

		fw.truthy(MultiBarBottomLeft.VuiFadeOut:IsPlaying(), "enabled bar fading out")
		fw.eq(MultiBarRight:GetAlpha(), 1, "disabled bar alpha")
	end)

	fw.it("fades the player frame out of combat", function()
		LoginWith({ PlayerFrame = true })

		fw.eq(PlayerFrame:GetAlpha(), 0, "player frame alpha out of combat")

		EnterCombat()

		fw.eq(PlayerFrame:GetAlpha(), 1, "player frame alpha in combat")
	end)

	fw.it("puts every chat tab back when chat fading is turned off", function()
		local context = LoginWith({ Chat = true })

		fw.eq(ChatFrame2Tab:GetAlpha(), 0, "second tab alpha while fading")

		-- faded, never hidden: a hidden tab can't be clicked
		fw.truthy(ChatFrame2Tab:IsShown(), "second tab shown while fading")

		-- what ticking the checkbox off does
		_G.MiniFaderDB.Frames.Chat = false
		context.Addon.Core.Registry:Refresh()

		fw.eq(ChatFrame2Tab:GetAlpha(), 0.2, "second tab alpha after")

		-- the client updating tab alpha must not put the fade back
		FCFTab_UpdateAlpha(ChatFrame2)

		fw.eq(ChatFrame2Tab:GetAlpha(), 0.2, "second tab alpha after a client update")
	end)

	fw.it("starts fading the chat tabs without a reload", function()
		local context = LoginWith({ Chat = false })

		_G.MiniFaderDB.Frames.Chat = true
		context.Addon.Core.Registry:Refresh()

		fw.eq(ChatFrame2Tab:GetAlpha(), 0, "second tab alpha")

		FCFTab_UpdateAlpha(ChatFrame2)

		fw.eq(ChatFrame2Tab:GetAlpha(), 0, "second tab alpha after a client update")
	end)

	fw.it("sets the micro menu scanner up once, not once per loading screen", function()
		LoginWith({})

		local before = WowMock.AddonFrameCount()

		WowMock.FireEvent("PLAYER_ENTERING_WORLD")
		WowMock.RunTimers()

		fw.eq(WowMock.AddonFrameCount(), before, "frames left behind by a second loading screen")
	end)

	fw.it("brings back every frame in a group when one of them is hovered", function()
		local context = LoginWith({})
		local fader = context.Addon.Core.Fader

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
		local fader = context.Addon.Core.Fader

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
		local fader = context.Addon.Core.Fader

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
		local fader = context.Addon.Core.Fader

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
		local fader = context.Addon.Core.Fader

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

	fw.it("schedules a single fade-out timer for a group even when more than one of its frames leaves", function()
		local context = LoginWith({})
		local fader = context.Addon.Core.Fader

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

		-- The mouse crossing between two buttons fires a leave on both frames in the same group.
		first:GetScript("OnLeave")(first)
		second:GetScript("OnLeave")(second)

		WowMock.AdvanceTime(4)

		fw.eq(WowMock.RunTimers(), 1, "only the group's own, most recently scheduled timer survives")
	end)

	fw.it("treats a deeply nested child under the mouse as still hovering its ancestor's group", function()
		local context = LoginWith({})
		local fader = context.Addon.Core.Fader

		local target = CreateFrame("Frame", nil, UIParent)
		target:EnableMouse(true)

		fader:RegisterFade({
			Target = target,
			ShouldFade = function()
				return true
			end,
		})

		target:SetAlpha(1)
		target:GetScript("OnLeave")(target)

		-- OnEnter/OnLeave fire by screen position rather than frame nesting, so what the
		-- client reports under the cursor can be an unwatched descendant several levels down
		-- while the frame that owns the group is still the one carrying the focus flag
		local mid = CreateFrame("Frame", nil, target)
		local deepChild = CreateFrame("Frame", nil, mid)

		target.VuiHasFocus = true

		WithGlobals({
			GetMouseFoci = function()
				return { deepChild }
			end,
		}, function()
			WowMock.AdvanceTime(4)
			WowMock.RunTimers()

			fw.falsy(target.VuiFadeOut:IsPlaying(), "fade-out suppressed by the hovered descendant")
		end)
	end)

	fw.it("does not treat a frame outside any group as hovering it", function()
		local context = LoginWith({})
		local fader = context.Addon.Core.Fader

		local target = CreateFrame("Frame", nil, UIParent)
		target:EnableMouse(true)

		fader:RegisterFade({
			Target = target,
			ShouldFade = function()
				return true
			end,
		})

		target:SetAlpha(1)
		target:GetScript("OnLeave")(target)

		local unrelated = CreateFrame("Frame", nil, UIParent)

		WithGlobals({
			GetMouseFoci = function()
				return { unrelated }
			end,
		}, function()
			WowMock.AdvanceTime(4)
			WowMock.RunTimers()

			fw.truthy(target.VuiFadeOut:IsPlaying(), "fade-out proceeded, nothing relevant was hovered")
		end)
	end)

	fw.it("keeps the alpha where a fade-in reached when a fade-out interrupts it", function()
		local context = LoginWith({})
		local fader = context.Addon.Core.Fader

		local target = CreateFrame("Frame", nil, UIParent)
		target:EnableMouse(true)

		fader:RegisterFade({
			Target = target,
			ShouldFade = function()
				return true
			end,
		})

		target:GetScript("OnEnter")(target)
		fw.truthy(target.VuiFadeIn:IsPlaying(), "fade-in under way")

		-- stands in for the fade-in having reached partway before something calls for a
		-- fade-out; the mock does not animate alpha on its own
		target:SetAlpha(0.4)

		-- The mock's Stop() never touches alpha on its own, so this stands in for a real
		-- animation group leaving the frame at a different alpha than where it was last read;
		-- only the source's own restoring SetAlpha call can bring it back to 0.4 afterward.
		local realStop = target.VuiFadeIn.Stop
		target.VuiFadeIn.Stop = function(self, ...)
			target:SetAlpha(0.9)
			return realStop(self, ...)
		end

		fader:Refresh(true)

		fw.falsy(target.VuiFadeIn:IsPlaying(), "fade-in was stopped")
		fw.eq(target:GetAlpha(), 0.4, "alpha held where the fade-in reached rather than snapping")
	end)
end)
