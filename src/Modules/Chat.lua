---@type string, table
local _, addon = ...
---@type Fader
local fader = addon.Core.Fader
---@type Registry
local registry = addon.Core.Registry

---@class ChatModule
local M = registry:Add({
	Key = "Chat",
	Title = "Chat",
	Tooltip = "Fade the chat tabs.",
	Default = false,
})

addon.Modules.Chat = M

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

function M:Refresh()
	local tab = 1
	local chatFrame = _G["ChatFrame" .. tab]
	local fade = registry:IsEnabled(M.Key)
	-- 0.2 is what Blizzard rests an unfocused tab at
	local tabAlpha = fade and 0 or 0.2

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
			bg,
		}

		for _, frame in pairs(frames) do
			if fade then
				frame:Hide()
			else
				frame:Show()
			end
		end

		if chatFrame.MiniFaderBackground then
			if fade then
				chatFrame.MiniFaderBackground:Show()
			else
				chatFrame.MiniFaderBackground:Hide()
			end
		end

		tab = tab + 1
		chatFrame = _G["ChatFrame" .. tab]
	end

	-- Every tab, including the ones whose chat frame hasn't been created yet, because a tab left
	-- at zero from an earlier fade would come back invisible. Alpha only: a hidden tab can't be
	-- clicked, and Blizzard owns which tabs are shown in the first place.
	tab = 1
	local nextTab = _G["ChatFrame" .. tab .. "Tab"]

	while nextTab ~= nil do
		nextTab:SetAlpha(tabAlpha)
		nextTab.noMouseAlpha = tabAlpha

		tab = tab + 1
		nextTab = _G["ChatFrame" .. tab .. "Tab"]
	end

	if fade then
		-- show tabs instantly on mouseover
		CHAT_TAB_SHOW_DELAY = 0
	else
		CHAT_TAB_SHOW_DELAY = 0.2
	end
end

-- Runs at ADDON_LOADED rather than on the first loading screen, so the tab alpha hook is in
-- place before the client uses it.
function M:Init()
	-- Hooked whatever the setting says and checked on each call, so turning fading on or off
	-- takes effect there and then. A hook installed once can't be taken back off.
	if FCFTab_UpdateAlpha then
		hooksecurefunc("FCFTab_UpdateAlpha", function(cf)
			if not registry:IsEnabled(M.Key) then
				return
			end

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
					return registry:IsEnabled(M.Key)
				end,
			})

			-- we show it later in Refresh
			customBg:Hide()
		end

		if buttonFrame then
			fader:RegisterFade({
				Target = buttonFrame,
				MouseFrame = chatFrame,
				EnableMouse = true,
				TimeUntilFadeOut = timeUntilFadeOut,
				ShouldFade = function()
					return registry:IsEnabled(M.Key)
				end,
			})
		end

		if QuickJoinToastButton then
			fader:RegisterFade({
				Target = QuickJoinToastButton,
				MouseFrame = ChatFrame1,
				TimeUntilFadeOut = timeUntilFadeOut,
				ShouldFade = function()
					return registry:IsEnabled(M.Key)
				end,
			})
		end

		tab = tab + 1
		chatFrame = _G["ChatFrame" .. tab]
	end
end
