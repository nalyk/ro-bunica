--!strict
-- Magazinul pe Robux: permisele („Pentru totdeauna”) și produsele („Acum”), din Config/Monetization.
-- Prețul vine de la Roblox (MarketplaceService), deci e mereu cel real; permisele deținute apar „Al tău”.
-- Cumpărarea se face prin fereastra Roblox; serverul acordă efectul (MonetizationService). Unde PolicyService
-- restricționează cumpărăturile cu rezultate aleatorii, ce duce la ele nu se arată (Domain/Policy).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Monetization)
local Policy = require(Shared.Domain.Policy)
local StoreIcons = require(Shared.Config.StoreIcons)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)

local StorePanel = {}

local ROW_HEIGHT = 84

local panel: Frame
local scroll: ScrollingFrame

type Row = { kind: "pass" | "product", key: string, id: number, buy: TextButton }
local rows: { Row } = {}
local prices: { [number]: number } = {}

local function price(id: number, infoType: Enum.InfoType): number?
	if prices[id] then
		return prices[id]
	end
	local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
	if ok and info and type(info.PriceInRobux) == "number" then
		prices[id] = info.PriceInRobux
		return info.PriceInRobux
	end
	return nil
end

local function refresh()
	local owned = ClientState.state.passes or {}
	for _, row in rows do
		if row.kind == "pass" and owned[row.key] then
			UI.setText(row.buy, ClientState.t("ui.owned"))
			UI.setSwatch(row.buy, "wheat")
		else
			local robux = prices[row.id]
			UI.setText(row.buy, if robux then "R$ " .. tostring(robux) else "…")
			UI.setSwatch(row.buy, "vine")
		end
	end
end

local function header(text: string, order: number)
	local label = UI.capText(
		UI.label({
			Size = UDim2.new(1, -12, 0, 30),
			Text = text,
			TextColor3 = Theme.swatches.ie.dark,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order,
			Parent = scroll,
		}),
		22
	)
	return label
end

local function row(kind: "pass" | "product", key: string, id: number, order: number)
	local frame = UI.frame({ Size = UDim2.new(1, -12, 0, ROW_HEIGHT), LayoutOrder = order, Parent = scroll })
	local disc = UI.frame({
		Size = UDim2.fromOffset(ROW_HEIGHT - 12, ROW_HEIGHT - 12),
		Position = UDim2.fromOffset(6, 6),
		BackgroundColor3 = Theme.swatches.wheat.light,
		Parent = frame,
	})
	local corner = disc:FindFirstChildWhichIsA("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = disc
	local iconId = StoreIcons[key]
	if iconId then
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Image = "rbxassetid://" .. iconId
		image.ScaleType = Enum.ScaleType.Fit
		image.Size = UDim2.fromScale(0.86, 0.86)
		image.Position = UDim2.fromScale(0.07, 0.07)
		image.Parent = disc
	end
	local prefix = if kind == "pass" then "pass." else "product."
	UI.capText(
		UI.label({
			Size = UDim2.new(0.6, -(ROW_HEIGHT + 4), 0.46, 0),
			Position = UDim2.new(0, ROW_HEIGHT + 2, 0.08, 0),
			Text = ClientState.t(prefix .. key),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		}),
		19
	)
	UI.capText(
		UI.label({
			Size = UDim2.new(0.6, -(ROW_HEIGHT + 4), 0.32, 0),
			Position = UDim2.new(0, ROW_HEIGHT + 2, 0.56, 0),
			Text = ClientState.t(prefix .. key .. ".desc"),
			TextColor3 = Theme.inkSoft,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		}),
		15
	)
	local buy = UI.button({
		Size = UDim2.new(0.3, -10, 0, ROW_HEIGHT - 26),
		Position = UDim2.new(0.69, 0, 0, 10),
		Text = "…",
		swatch = "vine",
		Parent = frame,
	}, function()
		local player = Players.LocalPlayer
		if kind == "pass" then
			if not (ClientState.state.passes or {})[key] then
				MarketplaceService:PromptGamePassPurchase(player, id)
			end
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)
	table.insert(rows, { kind = kind, key = key, id = id, buy = buy })
end

-- Politica jucătorului, din atributele puse de server (până sosesc: restricționat)
local function policy(): Policy.Policy
	local player = Players.LocalPlayer
	return {
		randomRestricted = player:GetAttribute("PaidRandomRestricted") ~= false,
		tradingAllowed = player:GetAttribute("PaidTradingAllowed") == true,
	}
end

local function build()
	UI.clear(scroll)
	table.clear(rows)
	local current = policy()
	local order = 0
	order += 1
	header(ClientState.t("ui.passes"), order)
	for _, pass in Config.passes do
		if Policy.canBuy(pass, current) then
			order += 1
			row("pass", pass.key, pass.id, order)
		end
	end
	order += 1
	header(ClientState.t("ui.products"), order)
	for _, product in Config.products do
		if product.id ~= 0 and Policy.canBuy(product, current) then
			order += 1
			row("product", product.key, product.id, order)
		end
	end
	refresh()
	-- prețurile reale, încărcate în fundal
	task.spawn(function()
		for _, r in rows do
			price(r.id, if r.kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product)
		end
		refresh()
	end)
end

function StorePanel.toggle()
	UI.show(panel, not panel.Visible)
	if panel.Visible then
		refresh()
	end
end

-- Numărul de rânduri (pentru teste)
function StorePanel.rowCount(): number
	return #rows
end

function StorePanel.start()
	panel, scroll = UI.panel(ClientState.t("ui.store"), function()
		UI.show(panel, false)
	end)
	build()
	Players.LocalPlayer:GetAttributeChangedSignal("PaidRandomRestricted"):Connect(build)
	ClientState.onChanged(function()
		if panel.Visible then
			refresh()
		end
	end)
end

return StorePanel
