--!strict
-- Bazarul pe client: lângă bazar apare butonul „Bazarul”; panoul arată ce vând ceilalți (cu „Cumpără”),
-- taraba ta (cu „Retrage”) și creaturile din beci de pus la vânzare (la 1×, 2× sau 4× valoarea lor).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Economy = require(Shared.Domain.Economy)
local Market = require(Shared.Domain.Market)
local Creatures = require(Shared.Config.Creatures)
local TradeConfig = require(Shared.Config.Trade)
local VillageLayout = require(Shared.Domain.VillageLayout)
local ClientState = require(script.Parent.ClientState)
local UI = require(script.Parent.UI)

local MarketPanel = {}

local REACH = 45
local bazaar = VillageLayout.build().sites.bazar
local button: TextButton
local panel: Frame
local scroll: ScrollingFrame
local snapshot: { listings: { any }, stalls: number, sunday: boolean } =
	{ listings = {}, stalls = 8, sunday = false }

local function render()
	UI.clear(scroll)
	UI.list(scroll, Enum.FillDirection.Vertical, 6)
	local me = Players.LocalPlayer.UserId
	local order = 0
	local function add(props: { [string]: any }, onClick: (() -> ())?)
		order += 1
		props.LayoutOrder = order
		props.Size = UDim2.new(1, -12, 0, 44)
		props.Parent = scroll
		if onClick then
			UI.button(props, onClick)
		else
			UI.label(props)
		end
	end
	if snapshot.sunday then
		add({ Text = "🎪 " .. ClientState.t("market.sunday") })
	end
	local any = false
	for _, listing in snapshot.listings do
		if listing.seller ~= me then
			any = true
			add({
				Text = string.format(
					"%s · %s lei · %s",
					ClientState.t("creature." .. listing.creature),
					Economy.formatShort(listing.price),
					listing.sellerName
				),
				swatch = if (ClientState.state.lei or 0) >= listing.price then "wheat" else "stone",
				icon = "lei",
			}, function()
				Net.get("Market"):FireServer("buy", listing.id)
			end)
		end
	end
	if not any then
		add({ Text = ClientState.t("market.empty") })
	end
	add({ Text = "🧺 " .. ClientState.t("market.yours") })
	for _, listing in snapshot.listings do
		if listing.seller == me then
			add({
				Text = string.format(
					"%s · %s lei · %s",
					ClientState.t("creature." .. listing.creature),
					Economy.formatShort(listing.price),
					ClientState.t("market.unlist")
				),
				swatch = "plum",
			}, function()
				Net.get("Market"):FireServer("unlist", listing.id)
			end)
		end
	end
	for _, record in ClientState.state.cellar or {} do
		local def = Creatures.byId[record.id]
		if
			not record.soul
			and not record.listed
			and not (def and TradeConfig.excludedRarities[def.rarity])
		then
			local value = Economy.sellPrice(record)
			local low, high = Market.priceRange(record)
			for _, factor in { 1, 2, 4 } do
				local price = math.clamp(math.floor(value * factor), low, high)
				add({
					Text = string.format(
						"%s → %s lei",
						ClientState.t("creature." .. record.id),
						Economy.formatShort(price)
					),
					swatch = "sky",
				}, function()
					Net.get("Market"):FireServer("list", record.uid, price)
				end)
			end
		end
	end
end

function MarketPanel.toggle()
	UI.show(panel, not panel.Visible)
	if panel.Visible then
		Net.get("Market"):FireServer("refresh")
		render()
	end
end

-- Pentru playtest
function MarketPanel.debugState(): { [string]: any }
	return { button = button.Visible, visible = panel.Visible, listings = #snapshot.listings }
end

function MarketPanel.start()
	button = UI.button({
		Name = "MarketButton",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -90),
		Size = UDim2.fromOffset(200, 56),
		Text = "🛒 " .. ClientState.t("market.open"),
		swatch = "wheat",
		Visible = false,
		Parent = UI.screen(),
	}, MarketPanel.toggle)
	panel, scroll = UI.panel(ClientState.t("market.title"), function()
		UI.show(panel, false)
	end)
	Net.get("Market").OnClientEvent:Connect(function(data)
		snapshot = data
		if panel.Visible then
			render()
		end
	end)
	ClientState.onChanged(function()
		if panel.Visible then
			render()
		end
	end)
	RunService.Heartbeat:Connect(function()
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		-- unde schimbul de lucruri plătite nu e permis (PolicyService), bazarul nu apare
		local isNear = root ~= nil
			and Players.LocalPlayer:GetAttribute("PaidTradingAllowed") == true
			and Vector3.new(root.Position.X - bazaar.X, 0, root.Position.Z - bazaar.Z).Magnitude <= REACH
		if button.Visible ~= isNear then
			button.Visible = isNear
		end
	end)
end

return MarketPanel
