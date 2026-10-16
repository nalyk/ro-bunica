--!strict
-- Beciul: creaturile expuse și cele ascunse; mutare și vânzare.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Economy = require(Shared.Domain.Economy)
local ClientState = require(script.Parent.ClientState)
local UI = require(script.Parent.UI)

local CellarPanel = {}

local panel: Frame
local scroll: ScrollingFrame

local function describe(record: { id: string, size: string, mutation: string? }): string
	local parts = {}
	if record.mutation then
		table.insert(parts, ClientState.t("mutation." .. record.mutation))
	end
	local size = ClientState.t("size." .. record.size)
	if size ~= "" then
		table.insert(parts, size)
	end
	table.insert(parts, ClientState.t("creature." .. record.id))
	return table.concat(parts, " ")
end

local function row(record: any, order: number, displayed: boolean, pedestalKey: string?)
	local creature = Creatures.byId[record.id]
	if not creature then
		return
	end
	local rarity = Rarities.byId[creature.rarity]
	local frame = UI.frame({ Size = UDim2.new(1, -12, 0, 56), LayoutOrder = order, Parent = scroll })
	UI.label({
		Size = UDim2.new(0.45, -10, 0.6, 0),
		Position = UDim2.fromOffset(10, 2),
		Text = describe(record),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	UI.label({
		Size = UDim2.new(0.45, -10, 0.35, 0),
		Position = UDim2.new(0, 10, 0.6, 0),
		Text = ClientState.t("rarity." .. creature.rarity)
			.. " · "
			.. ClientState.t("ui.perSecond", { Economy.formatShort(Economy.incomePerSecond(record)) }),
		TextColor3 = rarity.color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	UI.button({
		Size = UDim2.new(0.25, -6, 1, -12),
		Position = UDim2.new(0.46, 0, 0, 6),
		Text = if displayed then ClientState.t("ui.hide") else ClientState.t("ui.display"),
		BackgroundColor3 = UI.colors.night,
		Parent = frame,
	}, function()
		if displayed and pedestalKey then
			Net.get("MoveToCellar"):FireServer(pedestalKey)
		else
			Net.get("MoveToPedestal"):FireServer(record.uid)
		end
	end)
	UI.button({
		Size = UDim2.new(0.27, -6, 1, -12),
		Position = UDim2.new(0.72, 0, 0, 6),
		Text = ClientState.t("ui.sell") .. " " .. Economy.formatShort(Economy.sellPrice(record)),
		BackgroundColor3 = UI.colors.green,
		Parent = frame,
	}, function()
		Net.get("Sell"):FireServer(record.uid)
	end)
end

local function render()
	UI.clear(scroll)
	local state = ClientState.state
	local order = 0
	local keys = {}
	for key in state.pedestals or {} do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)
	for _, key in keys do
		order += 1
		row(state.pedestals[key], order, true, key)
	end
	for _, record in state.cellar or {} do
		order += 1
		row(record, order, false, nil)
	end
end

function CellarPanel.toggle()
	UI.show(panel, not panel.Visible)
	if panel.Visible then
		render()
	end
end

function CellarPanel.start()
	panel, scroll = UI.panel(ClientState.t("ui.cellar"), function()
		UI.show(panel, false)
	end)
	ClientState.onChanged(function()
		if panel.Visible then
			render()
		end
	end)
end

return CellarPanel
