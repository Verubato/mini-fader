local _, addon = ...
---@type MiniFramework
local mini = addon.Framework
local eventsFrame
---@type Config
local db
---@type Fader
local fader = addon.Fader

local function RegisterBuffsButton()
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
			return db.Frames.CollapseAndExpandButton
		end,
	})

	fader:RegisterFade({
		Target = btn,
		-- when hover mouse over BuffFrame, show the button
		MouseFrame = BuffFrame,
		ShouldFade = function()
			return db.Frames.CollapseAndExpandButton
		end,
	})
end

local function RegisterBags()
	if not BagsBar then
		return
	end

	fader:RegisterFade({
		Target = BagsBar,
		IncludeChildren = true,
		ShouldFade = function()
			return db.Frames.BagsBar
		end,
	})
end

local function RegisterMicroMenu()
	if not MicroMenu then
		return
	end

	fader:RegisterFade({
		Target = MicroMenu,
		IncludeChildren = true,
		EnableMouse = false,
		ShouldFade = function()
			return db.Frames.MicroMenu
		end,
	})
end

local function RegisterQuests()
	local target = ObjectiveTrackerFrame

	if not target then
		return
	end

	fader:RegisterFade({
		Target = target,
		EnableMouse = true,
		ShouldFade = function()
			if not db.Frames.ObjectiveTrackerFrame then
				return false
			end

			local inInstance, instanceType = IsInInstance()

			if not inInstance then
				return true
			end

			if instanceType == "pvp" or instanceType == "arena" then
				return db.Options.ObjectiveTracker.FadeWhen.InPvP
			end

			return db.Options.ObjectiveTracker.FadeWhen.InPvE
		end,
		Events = { "PLAYER_ENTERING_WORLD" },
	})
end

local function RegisterRaidFrameManager()
	local target = CompactRaidFrameManager

	if not target then
		return
	end

	fader:RegisterFade({
		Target = target,
		ShouldFade = function()
			return db.Frames.CompactRaidFrameManager
		end,
	})
end

local function RegisterXpAndRep()
	local target = StatusTrackingBarManager

	if not target then
		return
	end

	fader:RegisterFade({
		Target = target,
		EnableMouse = true,
		ShouldFade = function()
			return db.Frames.StatusTrackingBarManager
		end,
	})
end

local function ChatBackground(chatFrame, existingBg, alpha)
	local bg = CreateFrame("Frame", nil, chatFrame)
	bg:SetFrameLevel(math.max((chatFrame:GetFrameLevel() or 0) - 1, 0))
	bg:SetAllPoints(existingBg)

	local tex = bg:CreateTexture(nil, "BACKGROUND", nil, 0)
	tex:SetAllPoints(bg)
	tex:SetColorTexture(0, 0, 0, alpha)

	bg.Texture = tex

	return bg
end

local function RefreshChat()
	local tab = 1
	local chatFrame = _G["ChatFrame" .. tab]
	local chatFrameTab = _G["ChatFrame" .. tab .. "Tab"]
	local fade = db.Frames.Chat

	while chatFrame ~= nil do
		local bottomTexture = _G["ChatFrame" .. tab .. "BottomTexture"]
		local topTexture = _G["ChatFrame" .. tab .. "TopTexture"]
		local rightTexture = _G["ChatFrame" .. tab .. "RightTexture"]
		local leftTexture = _G["ChatFrame" .. tab .. "LeftTexture"]
		local topRightTexture = _G["ChatFrame" .. tab .. "TopRightTexture"]
		local topLeftTexture = _G["ChatFrame" .. tab .. "TopLeftTexture"]
		local bottomRightTexture = _G["ChatFrame" .. tab .. "BottomRightTexture"]
		local bottomLeftTexture = _G["ChatFrame" .. tab .. "BottomLeftTexture"]
		local bg = chatFrame.Background

		local frames = {
			bottomTexture,
			topTexture,
			rightTexture,
			leftTexture,
			topRightTexture,
			topLeftTexture,
			bottomRightTexture,
			bottomLeftTexture,
			chatFrameTab,
			bg,
		}

		for _, frame in pairs(frames) do
			if fade then
				frame:Hide()
			else
				frame:Show()
			end
		end

		if fade then
			chatFrameTab.noMouseAlpha = 0

			if chatFrame.MiniFaderBackground then
				chatFrame.MiniFaderBackground:Show()
			end

			chatFrameTab:SetAlpha(0)
		else
			chatFrameTab.noMouseAlpha = 0.2

			if chatFrame.MiniFaderBackground then
				chatFrame.MiniFaderBackground:Hide()
			end

			chatFrameTab:SetAlpha(0.2)
		end

		tab = tab + 1
		chatFrame = _G["ChatFrame" .. tab]
	end

	-- it seems chat frames are lazy loaded, so we can have tabs without frames
	-- don't :Show() tabs though as there are lots of hidden invalid tabs
	if fade then
		tab = 1
		chatFrameTab = _G["ChatFrame" .. tab .. "Tab"]

		while chatFrameTab ~= nil do
			chatFrameTab:SetAlpha(0)
			chatFrameTab.noMouseAlpha = 0

			tab = tab + 1
			chatFrameTab = _G["ChatFrame" .. tab .. "Tab"]
		end
	end

	if fade then
		-- show tabs instantly on mouseover
		CHAT_TAB_SHOW_DELAY = 0
	else
		CHAT_TAB_SHOW_DELAY = 0.2
	end
end

local function InitChat()
	if FCFTab_UpdateAlpha and db.Frames.Chat then
		hooksecurefunc("FCFTab_UpdateAlpha", function(cf)
			local chatTab = _G[cf:GetName() .. "Tab"]
			chatTab.noMouseAlpha = 0
			chatTab:SetAlpha(0)
		end)
	end

	local tab = 1
	local chatFrame = _G["ChatFrame" .. tab]
	local timeUntilFadeOut = 2

	while chatFrame ~= nil do
		local buttonFrame = _G["ChatFrame" .. tab .. "ButtonFrame"]
		local bg = chatFrame.Background

		if bg then
			local customBg = chatFrame.MiniFaderBackground or ChatBackground(chatFrame, bg, 0.25)
			chatFrame.MiniFaderBackground = customBg

			fader:RegisterFade({
				Target = customBg,
				MouseFrame = chatFrame,
				EnableMouse = true,
				FadeInToAlpha = 0.25,
				TimeUntilFadeOut = timeUntilFadeOut,
				FadeOutFromCurrentAlpha = true,
				ShouldFade = function()
					return db.Frames.Chat
				end,
			})

			-- we show it later in RefreshChat
			customBg:Hide()
		end

		if buttonFrame then
			fader:RegisterFade({
				Target = buttonFrame,
				MouseFrame = chatFrame,
				EnableMouse = true,
				TimeUntilFadeOut = timeUntilFadeOut,
				ShouldFade = function()
					return db.Frames.Chat
				end,
			})
		end

		if QuickJoinToastButton then
			fader:RegisterFade({
				Target = QuickJoinToastButton,
				MouseFrame = ChatFrame1,
				TimeUntilFadeOut = timeUntilFadeOut,
				ShouldFade = function()
					return db.Frames.Chat
				end,
			})
		end

		tab = tab + 1
		chatFrame = _G["ChatFrame" .. tab]
	end
end

local function Init()
	RegisterBuffsButton()
	RegisterBags()
	RegisterMicroMenu()
	RegisterQuests()
	RegisterRaidFrameManager()
	RegisterXpAndRep()
	RefreshChat()

	-- most notably the chat background needs to be refreshed
	fader:Refresh()
end

local function OnEnteringWorld()
	Init()
end

local function OnAddonLoaded()
	addon.Config:Init()

	db = mini:GetSavedVars()

	-- init chat early to hook before they are used
	InitChat()

	-- wait a bit later for frames to be created
	eventsFrame = CreateFrame("Frame")
	eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventsFrame:SetScript("OnEvent", OnEnteringWorld)
end

function addon:Refresh()
	RefreshChat()
end

mini:WaitForAddonLoad(OnAddonLoaded)
