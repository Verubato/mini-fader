---@type string, table
local _, addon = ...
local eventsFrame
local fadeInDuration = 0.5
local fadeOutDuration = 1
local timeUntilFadeOut = 3
local targets = {}

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

local function ScheduleFadeOut(mouseFrame, target, force)
	if target.VuiLeaveScheduled and not force then
		return
	end

	target.VuiLeaveScheduled = true

	local timeToWait = timeUntilFadeOut - (GetTime() - target.VuiLastLeft)

	C_Timer.After(timeToWait, function()
		local waited = GetTime() - target.VuiLastLeft

		if waited < timeUntilFadeOut then
			ScheduleFadeOut(mouseFrame, target, true)
			return
		end

		target.VuiLeaveScheduled = false

		if
			(not target.VuiShouldFade or target.VuiShouldFade())
			and target:GetAlpha() ~= 0
			and not AnyHasFocus(mouseFrame)
			and not target.VuiFadeOut:IsPlaying()
		then
			target.VuiFadeOut:Play()
		end
	end)
end

local function OnEnter(mouseFrame, target)
	mouseFrame.VuiHasFocus = true
	target.VuiLastEnter = GetTime()

	-- calling Stop() sets the final alpha value which we don't want
	-- so cache the current alpha and restore it after stopping the animation
	local alpha = target:GetAlpha()

	if target.VuiFadeOut:IsPlaying() then
		target.VuiFadeOut:Stop()
		target:SetAlpha(alpha)
	end

	if target:GetAlpha() ~= 1 and not target.VuiFadeIn:IsPlaying() then
		target.VuiFadeIn.Fade:SetFromAlpha(alpha)
		target.VuiFadeIn:Play()
	end
end

local function OnLeave(mouseFrame, target)
	mouseFrame.VuiHasFocus = false
	target.VuiLastLeft = GetTime()

	ScheduleFadeOut(mouseFrame, target)
end

local function WatchFrame(mouseFrame, target, focusKey, includeChildren, shouldFade, enableMouse)
	mouseFrame.VuiFocusKey = focusKey

	-- don't enable interactivity if told not to
	-- as this will intercept mouse events and prevent them from going to lower stack frames
	if enableMouse ~= nil and enableMouse then
		mouseFrame:EnableMouse(true)
	end

	if enableMouse or mouseFrame:IsMouseEnabled() then
		mouseFrame:HookScript("OnEnter", function()
			OnEnter(mouseFrame, target)
		end)
		mouseFrame:HookScript("OnLeave", function()
			OnLeave(mouseFrame, target)
		end)
	end

	if includeChildren then
		local children = { mouseFrame:GetChildren() }

		for _, child in ipairs(children) do
			-- don't recurse children
			WatchFrame(child, target, focusKey, false, shouldFade, enableMouse)
		end
	end

	target.VuiShouldFade = shouldFade
	targets[#targets + 1] = target
end

local function CreateFadeOut(frame)
	local ag = frame:CreateAnimationGroup()
	local fade = ag:CreateAnimation("Alpha")

	ag.Fade = fade

	fade:SetDuration(fadeOutDuration)
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0)
	fade:SetSmoothing("IN_OUT")

	ag:HookScript("OnFinished", function()
		frame:SetAlpha(0)
	end)

	return ag
end

local function CreateFadeIn(frame)
	local ag = frame:CreateAnimationGroup()
	local fade = ag:CreateAnimation("Alpha")

	ag.Fade = fade

	fade:SetDuration(fadeInDuration)
	fade:SetFromAlpha(frame:GetAlpha())
	fade:SetToAlpha(1)
	fade:SetSmoothing("IN_OUT")

	ag:HookScript("OnFinished", function()
		frame:SetAlpha(1)
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

	WatchFrame(
		mouseFrame,
		target,
		math.random(),
		options.IncludeChildren,
		options.ShouldFade,
		options.EnableMouse or options.EnableMouse == nil
	)

	if not options.ShouldFade or options.ShouldFade() then
		target:SetAlpha(0)
	else
		target:SetAlpha(1)
	end

	target.VuiFadeOut = CreateFadeOut(target)
	target.VuiFadeIn = CreateFadeIn(target)

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
---@field IncludeChildren boolean listen for children frame mouse events.
---@field EnableMouse boolean true by default, false means the mouse frame won't be configured for interactivity.
---@field ShouldFade fun(): boolean a predicate to determine if the target should fade in.
---@field Events table a list of events that trigger state changes to ShouldFade
