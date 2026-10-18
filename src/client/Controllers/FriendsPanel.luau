--!strict
-- Panoul „Prieteni”: tot ce ține de ceilalți oameni de pe server, într-un singur loc (în locul butoanelor
-- care pluteau peste HUD). Cheamă prieteni (invitația Roblox, +10% lei de prieten), Familie sau Rivali
-- (cât e un prieten pe server; se schimbă doar ziua, regula e pe server) și jucătorii de pe server, fiecare
-- cu butonul „Schimb”.

local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local ClientState = require(script.Parent.ClientState)
local TradePanel = require(script.Parent.TradePanel)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)

local FriendsPanel = {}

local me = Players.LocalPlayer
local panel: Frame
local scroll: ScrollingFrame
local shown = ""

function FriendsPanel.invite()
	local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, me)
	if ok and can then
		pcall(SocialService.PromptGameInvite, SocialService, me)
	end
end

local function row(height: number, order: number): Frame
	return UI.frame({ Size = UDim2.new(1, -12, 0, height), LayoutOrder = order, Parent = scroll })
end

local function text(parent: Instance, props: { [string]: any }, size: number): TextLabel
	props.Parent = parent
	if props.TextXAlignment == nil then
		props.TextXAlignment = Enum.TextXAlignment.Left
	end
	return UI.capText(UI.label(props), size)
end

-- Semnătura a ce se vede (jucătorii, familia, modul), ca lista să se refacă doar la schimbări
local function signature(): string
	local parts = {
		tostring(me:GetAttribute("FamilyMode")),
		tostring(me:GetAttribute("FamilyId")),
		tostring(me:GetAttribute("HasFriendHere")),
	}
	for _, player in Players:GetPlayers() do
		table.insert(parts, player.UserId .. ":" .. tostring(player:GetAttribute("FamilyId")))
	end
	return table.concat(parts, ",")
end

local function build()
	shown = signature()
	UI.clear(scroll)
	-- Cheamă prieteni
	local invite = row(70, 1)
	UI.button({
		Size = UDim2.new(0.5, -12, 0, 56),
		Position = UDim2.fromOffset(8, 7),
		Text = ClientState.t("ui.invite"),
		swatch = "ie",
		icon = "family",
		Parent = invite,
	}, FriendsPanel.invite)
	text(invite, {
		Size = UDim2.new(0.5, -16, 1, 0),
		Position = UDim2.new(0.5, 8, 0, 0),
		Text = ClientState.t("ui.inviteHint"),
		TextColor3 = Theme.swatches.vine.dark,
		TextWrapped = true,
	}, 17)

	-- Familie sau rivali (doar cu un prieten pe server)
	local familyId = me:GetAttribute("FamilyId")
	if me:GetAttribute("HasFriendHere") == true then
		local rival = me:GetAttribute("FamilyMode") == "Rival"
		text(row(30, 2), {
			Size = UDim2.new(1, -16, 1, 0),
			Position = UDim2.fromOffset(8, 0),
			Text = ClientState.t("ui.familyTitle"),
			TextColor3 = Theme.swatches.ie.dark,
		}, 20)
		local choice = row(84, 3)
		text(choice, {
			Size = UDim2.new(0.58, -12, 1, -8),
			Position = UDim2.fromOffset(8, 4),
			Text = ClientState.t(if rival then "ui.familyRivalBody" else "ui.familyBody"),
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Center,
		}, 16)
		UI.button({
			Size = UDim2.new(0.4, -10, 0, 56),
			Position = UDim2.new(0.6, 0, 0, 14),
			Text = ClientState.t(if rival then "ui.becomeFamily" else "ui.becomeRival"),
			swatch = if rival then "vine" else "ie",
			Parent = choice,
		}, function()
			Net.get("FamilyMode"):FireServer(if rival then "Family" else "Rival")
		end)
	end

	-- Jucătorii de pe server, cu schimbul
	local others = {}
	for _, player in Players:GetPlayers() do
		if player ~= me then
			table.insert(others, player)
		end
	end
	text(row(30, 4), {
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Text = if #others > 0 then ClientState.t("ui.onServer") else ClientState.t("ui.aloneOnServer"),
		TextColor3 = Theme.swatches.ie.dark,
	}, 20)
	for order, player in others do
		local line = row(62, 10 + order)
		local tag = if familyId ~= nil and player:GetAttribute("FamilyId") == familyId
			then ClientState.t("ui.tagFamily")
			else ""
		text(line, {
			Size = UDim2.new(0.55, -12, 1, 0),
			Position = UDim2.fromOffset(12, 0),
			Text = player.DisplayName .. (if tag ~= "" then "  ·  " .. tag else ""),
		}, 20)
		local userId = player.UserId
		-- schimburile doar unde PolicyService le permite (serverul verifică și partea celuilalt)
		if Players.LocalPlayer:GetAttribute("PaidTradingAllowed") ~= true then
			continue
		end
		UI.button({
			Size = UDim2.new(0.42, -8, 0, 48),
			Position = UDim2.new(0.57, 0, 0, 7),
			Text = ClientState.t("ui.tradeAsk"),
			swatch = "sky",
			icon = "trade",
			Parent = line,
		}, function()
			TradePanel.request(userId)
			UI.show(panel, false)
		end)
	end
end

function FriendsPanel.toggle()
	UI.show(panel, not panel.Visible)
	if panel.Visible then
		build()
	end
end

function FriendsPanel.start()
	panel, scroll = UI.panel(ClientState.t("ui.friends"), function()
		UI.show(panel, false)
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if panel.Visible and signature() ~= shown then
				build()
			end
		end
	end)
end

return FriendsPanel
