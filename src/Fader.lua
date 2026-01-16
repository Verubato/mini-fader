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

		if next == mouseFrame then
			return false
		end

		local parent = next:GetParent()

		if parent and parent ~= UIParent then
			table.insert(stack, parent)
		end

		next = table.remove(stack)
	end

	return false
end

local function StopAnimationPreserveAlpha(target, ag)
	if not ag:IsPlaying() then
		return
	end

	ag.VuiSuppressFinish = true

	local alpha = target:GetAlpha()
	ag:Stop()
	target:SetAlpha(alpha)

	ag.VuiSuppressFinish = false
end

local function ScheduleFadeOut(mouseFrame, target, force, timeUntilFadeOut)
	if target.VuiLeaveScheduled and not force then
		return
	end

	target.VuiLeaveScheduled = true

	timeUntilFadeOut = timeUntilFadeOut or defaultTimeUntilFadeOut
	local timeToWait = timeUntilFadeOut - (GetTime() - target.VuiLastLeft)

	local function TryFadeOut()
		if
			(not target.VuiShouldFade or target.VuiShouldFade())
			and target:GetAlpha() ~= 0
			and not AnyHasFocus(mouseFrame)
			and not target.VuiFadeOut:IsPlaying()
		then
			-- if fade-in is still playing, stop it
			StopAnimationPreserveAlpha(target, target.VuiFadeIn)

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
	target.VuiLastEnter = GetTime()

	if target.VuiFadeOutTimer then
		target.VuiFadeOutTimer:Cancel()
		target.VuiFadeOutTimer = nil
	end
	target.VuiLeaveScheduled = false

	StopAnimationPreserveAlpha(target, target.VuiFadeOut)

	if target:GetAlpha() ~= (fadeToAlpha or 1) and not target.VuiFadeIn:IsPlaying() then
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

	target.VuiShouldFade = options.ShouldFade
	targets[#targets + 1] = target
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
		if self.VuiSuppressFinish then
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
		if self.VuiSuppressFinish then
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

	WatchFrame(mouseFrame, target, math.random(), options.IncludeChildren, options)

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
