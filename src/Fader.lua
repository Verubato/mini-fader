---@type string, table
local _, addon = ...
local eventsFrame
local fadeInDuration = 0.5
local fadeOutDuration = 1
local defaultTimeUntilFadeOut = 3
local targets = {}

---@class Fader
local M = {}
addon.Fader = M

local function AnyHasFocus(mouseFrame)
	-- walk up the parent tree and see if anything has focus
	local focusedFrames = GetMouseFoci()
	local stack = {}

	for _, frame in ipairs(focusedFrames) do
		stack[#stack + 1] = frame
	end

	local next = table.remove(stack)

	while next do
		-- use the focusKey to determine which frame stack we're looking at
		if next.VuiHasFocus and next.VuiFocusKey == mouseFrame.VuiFocusKey then
			return true
		end

		-- don't traverse above mouseFrame, but don't return early —
		-- there may be other frames in the stack (from GetMouseFoci) still to check
		if next ~= mouseFrame then
			local parent = next:GetParent()

			if parent and parent ~= UIParent then
				table.insert(stack, parent)
			end
		end

		next = table.remove(stack)
	end

	return false
end

local function StopAnimationPreserveAlpha(target, ag)
	if not ag:IsPlaying() then
		return
	end

	local alpha = target:GetAlpha()
	ag.VuiSuppressFinish = true
	ag:Stop()
	-- intentionally NOT clearing VuiSuppressFinish here;
	-- OnFinished clears it, keeping the flag set regardless of sync/async firing
	target:SetAlpha(alpha)
end

local function ScheduleFadeOut(mouseFrame, target, force, timeUntilFadeOut)
	if target.VuiLeaveScheduled and not force then
		return
	end

	target.VuiLeaveScheduled = true

	timeUntilFadeOut = timeUntilFadeOut or defaultTimeUntilFadeOut
	local timeToWait = timeUntilFadeOut - (GetTime() - target.VuiLastLeft)

	local function TryFadeOut()
		-- if fade-in is still running, wait for it to finish before starting fade-out.
		-- GetAlpha() returns the animated value during animation, so the alpha != 0 check
		-- below would pass mid-fade-in, causing us to stop the fade-in prematurely.
		if target.VuiFadeIn:IsPlaying() then
			C_Timer.After(fadeInDuration, TryFadeOut)
			return
		end

		-- guard against stale C_Timer.After retries firing too early: a later OnLeave may
		-- have updated VuiLastLeft, so re-check that the full grace period has elapsed.
		if GetTime() - target.VuiLastLeft < timeUntilFadeOut then
			return
		end

		if
			(not target.VuiShouldFade or target.VuiShouldFade())
			and target:GetAlpha() ~= 0
			and not AnyHasFocus(mouseFrame)
			and not target.VuiFadeOut:IsPlaying()
		then
			-- always fade out from current alpha
			if target.VuiFadeOut and target.VuiFadeOut.Fade then
				target.VuiFadeOut.Fade:SetFromAlpha(target:GetAlpha())
			end

			target.VuiFadeOut:Play()
		end
	end

	if target.VuiFadeOutTimer then
		target.VuiFadeOutTimer:Cancel()
		target.VuiFadeOutTimer = nil
	end

	local function Fire()
		target.VuiLeaveScheduled = false
		target.VuiFadeOutTimer = nil
		TryFadeOut()
	end

	if timeToWait <= 0 then
		Fire()
		return
	end

	target.VuiFadeOutTimer = C_Timer.NewTimer(timeToWait, Fire)
end

local function OnEnter(mouseFrame, target, fadeToAlpha)
	mouseFrame.VuiHasFocus = true

	if target.VuiFadeOutTimer then
		target.VuiFadeOutTimer:Cancel()
		target.VuiFadeOutTimer = nil
	end
	target.VuiLeaveScheduled = false

	StopAnimationPreserveAlpha(target, target.VuiFadeOut)

	if target:GetAlpha() ~= (fadeToAlpha or 1) and not target.VuiFadeIn:IsPlaying() then
		if target.VuiFadeIn and target.VuiFadeIn.Fade then
			target.VuiFadeIn.Fade:SetFromAlpha(target:GetAlpha())
		end
		target.VuiFadeIn:Play()
	end
end

local function OnLeave(mouseFrame, target, timeUntilFadeOut)
	mouseFrame.VuiHasFocus = false
	target.VuiLastLeft = GetTime()

	ScheduleFadeOut(mouseFrame, target, false, timeUntilFadeOut)
end

---@param options FadeOptions
local function WatchFrame(mouseFrame, target, focusKey, includeChildren, options)
	mouseFrame.VuiFocusKey = focusKey

	-- don't enable interactivity if told not to
	-- as this will intercept mouse events and prevent them from going to lower stack frames
	if options.EnableMouse then
		mouseFrame:EnableMouse(true)
	end

	if options.EnableMouse or mouseFrame:IsMouseEnabled() then
		mouseFrame:HookScript("OnEnter", function()
			OnEnter(mouseFrame, target, options.FadeInToAlpha)
		end)
		mouseFrame:HookScript("OnLeave", function()
			OnLeave(mouseFrame, target, options.TimeUntilFadeOut)
		end)
	end

	if includeChildren then
		local children = { mouseFrame:GetChildren() }

		for _, child in ipairs(children) do
			-- don't recurse children
			WatchFrame(child, target, focusKey, false, options)
		end
	end

end

---@param options FadeOptions
local function CreateFadeOut(frame, options)
	local ag = frame:CreateAnimationGroup()
	local fade = ag:CreateAnimation("Alpha")

	ag.Fade = fade

	fade:SetDuration(options.FadeOutDuration or fadeOutDuration)
	fade:SetFromAlpha(options.FadeInToAlpha or 1) -- will be overridden at play-time
	fade:SetToAlpha(0)
	fade:SetSmoothing("IN_OUT")

	ag:HookScript("OnFinished", function(self)
		local suppress = self.VuiSuppressFinish
		self.VuiSuppressFinish = false
		if suppress then
			return
		end

		frame:SetAlpha(0)
	end)

	return ag
end

---@param options FadeOptions
local function CreateFadeIn(frame, options)
	local ag = frame:CreateAnimationGroup()
	local fade = ag:CreateAnimation("Alpha")
	ag.Fade = fade

	fade:SetDuration(options.FadeInDuration or fadeInDuration)
	fade:SetFromAlpha(frame:GetAlpha())
	fade:SetToAlpha(options.FadeInToAlpha or 1)
	fade:SetSmoothing("IN_OUT")

	ag:HookScript("OnFinished", function(self)
		local suppress = self.VuiSuppressFinish
		self.VuiSuppressFinish = false
		if suppress then
			return
		end

		frame:SetAlpha(options.FadeInToAlpha or 1)
	end)

	return ag
end

local function OnEvent()
	M:Refresh()
end

---Refreshes the fading state by rechecking the ShouldFade of each frame.
function M:Refresh()
	for i = 1, #targets do
		local target = targets[i]
		local shouldFade = target.VuiShouldFade

		if shouldFade then
			if shouldFade() then
				target:SetAlpha(0)
			else
				target:SetAlpha(1)
			end
		end
	end
end

---Registers a frame to be faded.
---@param options FadeOptions
function M:RegisterFade(options)
	local mouseFrame = options.MouseFrame or options.Target
	local target = options.Target

	-- Registration is driven from PLAYER_ENTERING_WORLD, which comes round again on every zone
	-- change. Without this each pass would stack another set of mouse hooks, leave the previous
	-- animation groups orphaned on the frame, and add one more entry to targets. Per target
	-- rather than a single flag, so a frame that only appears later still gets picked up.
	if target.VuiRegistered then
		return
	end

	target.VuiRegistered = true

	WatchFrame(mouseFrame, target, math.random(), options.IncludeChildren, options)

	target.VuiShouldFade = options.ShouldFade
	targets[#targets + 1] = target

	if not options.ShouldFade or options.ShouldFade() then
		target:SetAlpha(0)
	else
		target:SetAlpha(options.FadeInToAlpha or 1)
	end

	target.VuiFadeOut = CreateFadeOut(target, options)
	target.VuiFadeIn = CreateFadeIn(target, options)

	if options.Events then
		for i = 1, #options.Events do
			local event = options.Events[i]

			if not eventsFrame:IsEventRegistered(event) then
				eventsFrame:RegisterEvent(event)
			end
		end
	end
end

eventsFrame = CreateFrame("Frame")
eventsFrame:SetScript("OnEvent", OnEvent)

---@class FadeOptions
---@field Target table the target frame to fade
---@field MouseFrame table? an optional frame that when the mouse enters/leaves this frame, the target frame will fade in/out.
---@field TimeUntilFadeOut number? the number of seconds until the frame starts to fades out.
---@field FadeInToAlpha number? the end alpha value to fade to.
---@field FadeInDuration number? number in seconds it takes to fade in.
---@field FadeOutFromCurrentAlpha boolean? whether to use the current alpha when fading out.
---@field FadeOutDuration number? number in seconds it takes to fade out.
---@field IncludeChildren boolean? listen for children frame mouse events.
---@field EnableMouse boolean? true by default, false means the mouse frame won't be configured for interactivity.
---@field ShouldFade fun(): boolean? a predicate to determine if the target should fade in.
---@field Events table? a list of events that trigger state changes to ShouldFade
