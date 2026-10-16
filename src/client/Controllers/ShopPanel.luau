--!strict
-- Panoul tarabei cu semințe: fiecare rând arată creatura sculptată (ViewportFrame), numele, raritatea și
-- venitul, stocul și prețul. Rândurile se construiesc o dată pe stoc nou (modelele sunt grele); când se schimbă
-- doar banii, se actualizează textul și culoarea butoanelor.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Economy = require(Shared.Domain.Economy)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)
local CreaturePreview = require(script.Parent.CreaturePreview)

local ShopPanel = {}

local ROW_HEIGHT = 84

local panel: Frame
local scroll: ScrollingFrame
local restockLabel: TextLabel

type Row = { creatureId: string, price: number, stockLabel: TextLabel, buy: TextButton }
local rows: { Row } = {}
local builtFor = "" -- semnătura stocului pentru care sunt construite rândurile

local function stockSignature(): string
	local parts = {}
	for _, creature in Creatures.list do
		if creature.seedPrice and ClientState.shopStock[creature.id] then
			table.insert(parts, creature.id)
		end
	end
	return table.concat(parts, ",")
end

-- Doar ce se schimbă des: stocul și dacă îți permiți sămânța
local function refresh()
	local lei = ClientState.state.lei or 0
	for _, row in rows do
		local stock = ClientState.shopStock[row.creatureId] or 0
		row.stockLabel.Text = ClientState.t("ui.stock", { stock })
		UI.setSwatch(row.buy, if lei >= row.price and stock > 0 then "vine" else "stone")
	end
end

local function build()
	UI.clear(scroll)
	table.clear(rows)
	builtFor = stockSignature()
	for order, creature in Creatures.list do
		if not creature.seedPrice or not ClientState.shopStock[creature.id] then
			continue
		end
		local rarity = Rarities.byId[creature.rarity]
		local row =
			UI.frame({ Size = UDim2.new(1, -12, 0, ROW_HEIGHT), LayoutOrder = order, Parent = scroll })
		CreaturePreview.make({ id = creature.id, size = "Normal" }, rarity.color, ROW_HEIGHT - 8, row)
		UI.capText(
			UI.label({
				Size = UDim2.new(0.53, -(ROW_HEIGHT + 10), 0.5, -6),
				Position = UDim2.fromOffset(ROW_HEIGHT + 6, 8),
				Text = ClientState.t("creature." .. creature.id),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			}),
			19
		)
		UI.capText(
			UI.label({
				Size = UDim2.new(0.53, -(ROW_HEIGHT + 10), 0.32, 0),
				Position = UDim2.new(0, ROW_HEIGHT + 6, 0.55, 0),
				Text = ClientState.t("rarity." .. creature.rarity)
					.. " · "
					.. ClientState.t("ui.perSecond", { Economy.formatShort(creature.income) }),
				TextColor3 = rarity.color:Lerp(Theme.ink, 0.3), -- mai închis, lizibil pe hârtie
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			}),
			17
		)
		local stockLabel = UI.capText(
			UI.label({
				Size = UDim2.fromScale(0.12, 0.5),
				Position = UDim2.fromScale(0.53, 0.25),
				Text = "",
				Parent = row,
			}),
			26
		)
		local buy = UI.button({
			Size = UDim2.new(0.32, -10, 0, ROW_HEIGHT - 26),
			Position = UDim2.new(0.66, 0, 0, 10),
			Text = Economy.formatShort(creature.seedPrice) .. " " .. ClientState.t("ui.lei"),
			swatch = "stone",
			icon = "lei",
			Parent = row,
		}, function()
			Net.get("BuySeed"):FireServer(creature.id)
		end)
		table.insert(
			rows,
			{ creatureId = creature.id, price = creature.seedPrice, stockLabel = stockLabel, buy = buy }
		)
	end
	refresh()
end

local function update()
	if not panel.Visible then
		return
	end
	if stockSignature() ~= builtFor then
		build()
	else
		refresh()
	end
end

function ShopPanel.toggle()
	UI.show(panel, not panel.Visible)
	update()
end

function ShopPanel.start()
	panel, scroll = UI.panel(ClientState.t("ui.shop"), function()
		UI.show(panel, false)
	end)
	-- aprovizionarea, într-o bandă jos (sus e panglica titlului și butonul de închidere)
	scroll.Size = UDim2.new(1, -28, 1, -84)
	restockLabel = UI.capText(
		UI.label({
			Size = UDim2.new(1, -28, 0, 26),
			Position = UDim2.new(0, 14, 1, -38),
			Text = "",
			TextColor3 = Theme.inkSoft,
			Parent = panel,
		}),
		18
	)
	ClientState.onShopChanged(function()
		builtFor = "" -- stoc nou (sau aprovizionare): rândurile se refac la următoarea afișare
		update()
	end)
	ClientState.onChanged(update)
	task.spawn(function()
		while true do
			local left = ClientState.shopRestockAt - Workspace:GetServerTimeNow()
			restockLabel.Text = ClientState.t("ui.restockIn", { UI.formatTime(left) })
			task.wait(1)
		end
	end)
end

return ShopPanel
