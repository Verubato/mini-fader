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

---Whether anything belonging to a fade group is under the mouse.
local function AnyHasFocus(group)
	-- walk up the parent tree and see if anything has focus
	local focusedFrames = GetMouseFoci()
	local stack = {}

	for _, frame in ipairs(focusedFrames) do
		stack[#stack + 1] = frame
	end

	local next = table.remove(stack)

	while next do
		-- a frame can wake several groups, such as the chat window behind both the chat
		-- background and the chat buttons, so ask whether it wakes this one
		if next.VuiHasFocus and next.VuiFocusGroups and next.VuiFocusGroups[group] then
			return true
		end

		-- what's under the mouse is often an unwatched child of a watched frame,
		-- so keep climbing rather than stopping at the first one
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

	local alpha = target:GetAlpha()
	ag.VuiSuppressFinish = true
	ag:Stop()
	-- intentionally NOT clearing VuiSuppressFinish here;
	-- OnFinished clears it, keeping the flag set regardless of sync/async firing
	target:SetAlpha(alpha)
end

local function FadeIn(target)
	StopAnimationPreserveAlpha(target, target.VuiFadeOut)

	if target:GetAlpha() ~= target.VuiFadeInAlpha and not target.VuiFadeIn:IsPlaying() then
		-- always fade in from current alpha
		target.VuiFadeIn.Fade:SetFromAlpha(target:GetAlpha())
		target.VuiFadeIn:Play()
	end
end

local function FadeOut(target)
	if target.VuiFadeOut:IsPlaying() then
		return
	end

	StopAnimationPreserveAlpha(target, target.VuiFadeIn)

	if target:GetAlpha() == 0 then
		return
	end

	-- always fade out from current alpha
	target.VuiFadeOut.Fade:SetFromAlpha(target:GetAlpha())
	target.VuiFadeOut:Play()
end

local function CancelFadeOutTimer(group)
	if group.FadeOutTimer then
		group.FadeOutTimer:Cancel()
		group.FadeOutTimer = nil
	end
end

---One timer for the whole group: they all left the mouse at the same moment, and a bar with
---a dozen buttons on it would otherwise re-arm a timer per target on every button crossed.
local function ScheduleFadeOut(group, timeUntilFadeOut)
	timeUntilFadeOut = timeUntilFadeOut or defaultTimeUntilFadeOut

	local function Fire()
		group.FadeOutTimer = nil

		-- wait for a running fade-in to finish first. GetAlpha() returns the animated value
		-- during an animation, so FadeOut's alpha check would pass mid-fade-in and cut it off.
		for i = 1, #group.Targets do
			if group.Targets[i].VuiFadeIn:IsPlaying() then
				group.FadeOutTimer = C_Timer.NewTimer(fadeInDuration, Fire)
				return
			end
		end

		-- a later leave pushed the deadline out, so wait out whatever is left of it
		local remaining = timeUntilFadeOut - (GetTime() - group.LastLeft)

		if remaining > 0 then
			group.FadeOutTimer = C_Timer.NewTimer(remaining, Fire)
			return
		end

		if AnyHasFocus(group) then
			return
		end

		for i = 1, #group.Targets do
			local target = group.Targets[i]

			if not target.VuiShouldFade or target.VuiShouldFade() then
				FadeOut(target)
			end
		end
	end

	CancelFadeOutTimer(group)

	local timeToWait = timeUntilFadeOut - (GetTime() - group.LastLeft)

	if timeToWait <= 0 then
		Fire()
		return
	end

	group.FadeOutTimer = C_Timer.NewTimer(timeToWait, Fire)
end

local function OnEnter(mouseFrame, group)
	mouseFrame.VuiHasFocus = true

	CancelFadeOutTimer(group)

	for i = 1, #group.Targets do
		FadeIn(group.Targets[i])
	end
end

local function OnLeave(mouseFrame, group, timeUntilFadeOut)
	mouseFrame.VuiHasFocus = false
	group.LastLeft = GetTime()

	ScheduleFadeOut(group, timeUntilFadeOut)
end

---@param depth number how many levels of children also count as hover targets
---@param options FadeOptions
local function WatchFrame(mouseFrame, group, depth, options)
	if group.MouseFrames[mouseFrame] then
		return
	end

	group.MouseFrames[mouseFrame] = true

	local focusGroups = mouseFrame.VuiFocusGroups or {}
	focusGroups[group] = true
	mouseFrame.VuiFocusGroups = focusGroups

	-- don't enable interactivity if told not to
	-- as this will intercept mouse events and prevent them from going to lower stack frames
	if options.EnableMouse then
		mouseFrame:EnableMouse(true)
	end

	if options.EnableMouse or mouseFrame:IsMouseEnabled() then
		mouseFrame:HookScript("OnEnter", function()
			OnEnter(mouseFrame, group)
		end)
		mouseFrame:HookScript("OnLeave", function()
			OnLeave(mouseFrame, group, options.TimeUntilFadeOut)
		end)
	end

	if depth > 0 then
		local children = { mouseFrame:GetChildren() }

		for _, child in ipairs(children) do
			WatchFrame(child, group, depth - 1, options)
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

---@param options FadeOptions
local function SetupTarget(target, group, options)
	target.VuiFadeGroup = group
	target.VuiFadeInAlpha = options.FadeInToAlpha or 1
	target.VuiShouldFade = options.ShouldFade
	target.VuiFadeOut = CreateFadeOut(target, options)
	target.VuiFadeIn = CreateFadeIn(target, options)

	group.Targets[#group.Targets + 1] = target
	targets[#targets + 1] = target

	if not options.ShouldFade or options.ShouldFade() then
		target:SetAlpha(0)
	else
		target:SetAlpha(target.VuiFadeInAlpha)
	end
end

---The group these frames already belong to, if any of them has been registered before.
local function FindGroup(groupTargets)
	for i = 1, #groupTargets do
		local group = groupTargets[i].VuiFadeGroup

		if group then
			return group
		end
	end

	return nil
end

local function OnEvent()
	-- the game changed under the player rather than the player asking for it,
	-- so ease the frames away instead of snapping them out of existence
	M:Refresh(true)
end

---Refreshes the fading state by rechecking the ShouldFade of each frame.
---@param animate boolean? fade a frame out rather than snapping it to invisible.
function M:Refresh(animate)
	for i = 1, #targets do
		local target = targets[i]
		local shouldFade = target.VuiShouldFade

		if shouldFade then
			if not shouldFade() then
				-- a frame that has stopped fading has to show now, mid-animation or not:
				-- combat starts this way, and a running fade-out would hide it again
				StopAnimationPreserveAlpha(target, target.VuiFadeIn)
				StopAnimationPreserveAlpha(target, target.VuiFadeOut)
				target:SetAlpha(target.VuiFadeInAlpha)
			elseif not animate then
				StopAnimationPreserveAlpha(target, target.VuiFadeIn)
				StopAnimationPreserveAlpha(target, target.VuiFadeOut)
				target:SetAlpha(0)
			elseif not target.VuiFadeGroup.FadeOutTimer and not AnyHasFocus(target.VuiFadeGroup) then
				-- a group already counting down keeps its grace period; it fades on its own
				FadeOut(target)
			end
		end
	end
end

---Registers one or more frames to be faded. Frames registered together fade as one, so
---hovering any of them brings back the whole set.
---@param options FadeOptions
function M:RegisterFade(options)
	local groupTargets = options.Targets or { options.Target }

	if #groupTargets == 0 then
		return
	end

	-- true means the direct children too, a number says how many levels deep to go
	local depth = options.IncludeChildren == true and 1 or options.IncludeChildren or 0
	local group = FindGroup(groupTargets) or { Targets = {}, MouseFrames = {} }

	-- Registration is driven from PLAYER_ENTERING_WORLD, which comes round again on every zone
	-- change, so every step below skips whatever it did last time. Otherwise each pass would
	-- stack another set of mouse hooks, leave the previous animation groups orphaned on the
	-- frame, and add one more entry to targets. Per frame rather than a single flag, so a
	-- frame that only appears later still gets picked up.
	for i = 1, #groupTargets do
		local target = groupTargets[i]

		if not target.VuiFadeGroup then
			SetupTarget(target, group, options)

			-- a frame is its own hover target unless told otherwise
			if not options.MouseFrame then
				WatchFrame(target, group, depth, options)
			end
		end
	end

	if options.MouseFrame then
		WatchFrame(options.MouseFrame, group, depth, options)
	end

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
---@field Targets table? several frames that fade as one, used instead of Target
---@field MouseFrame table? an optional frame that when the mouse enters/leaves this frame, the target frame will fade in/out.
---@field TimeUntilFadeOut number? the number of seconds until the frame starts to fades out.
---@field FadeInToAlpha number? the end alpha value to fade to.
---@field FadeInDuration number? number in seconds it takes to fade in.
---@field FadeOutFromCurrentAlpha boolean? whether to use the current alpha when fading out.
---@field FadeOutDuration number? number in seconds it takes to fade out.
---@field IncludeChildren boolean|number? listen for children frame mouse events, true for one level deep or a number of levels.
---@field EnableMouse boolean? true by default, false means the mouse frame won't be configured for interactivity.
---@field ShouldFade fun(): boolean? a predicate to determine if the target should fade in.
---@field Events table? a list of events that trigger state changes to ShouldFade
