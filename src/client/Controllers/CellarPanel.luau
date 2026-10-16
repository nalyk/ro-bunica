--!strict
-- Beciul: creaturile expuse și cele ascunse; mutare și vânzare.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Economy = require(Shared.Domain.Economy)
local ClientState = require(script.Parent.ClientState)
local UI = require(script.Parent.UI)
local Theme = require(script.Parent.Theme)
local CreaturePreview = require(script.Parent.CreaturePreview)

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

local ROW_HEIGHT = 84
local builtFor = "" -- semnătura listei pentru care sunt construite rândurile (modelele sunt grele)

local function row(record: any, order: number, displayed: boolean, pedestalKey: string?)
	local creature = Creatures.byId[record.id]
	if not creature then
		return
	end
	local rarity = Rarities.byId[creature.rarity]
	local frame = UI.frame({ Size = UDim2.new(1, -12, 0, ROW_HEIGHT), LayoutOrder = order, Parent = scroll })
	CreaturePreview.make(record, rarity.color, ROW_HEIGHT - 8, frame)
	UI.capText(
		UI.label({
			Size = UDim2.new(0.46, -(ROW_HEIGHT + 10), 0.5, -6),
			Position = UDim2.fromOffset(ROW_HEIGHT + 6, 8),
			Text = describe(record),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		}),
		19
	)
	UI.capText(
		UI.label({
			Size = UDim2.new(0.46, -(ROW_HEIGHT + 10), 0.32, 0),
			Position = UDim2.new(0, ROW_HEIGHT + 6, 0.55, 0),
			Text = ClientState.t("rarity." .. creature.rarity)
				.. " · "
				.. ClientState.t("ui.perSecond", { Economy.formatShort(Economy.incomePerSecond(record)) }),
			TextColor3 = rarity.color:Lerp(Theme.ink, 0.3), -- mai închis, lizibil pe hârtie
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		}),
		17
	)
	UI.button({
		Size = UDim2.new(0.25, -6, 0, ROW_HEIGHT - 26),
		Position = UDim2.new(0.47, 0, 0, 10),
		Text = if displayed then ClientState.t("ui.hide") else ClientState.t("ui.display"),
		swatch = if displayed then "plum" else "sky",
		icon = if displayed then "cellar" else nil,
		Parent = frame,
	}, function()
		if displayed and pedestalKey then
			Net.get("MoveToCellar"):FireServer(pedestalKey)
		else
			Net.get("MoveToPedestal"):FireServer(record.uid)
		end
	end)
	UI.button({
		Size = UDim2.new(0.27, -6, 0, ROW_HEIGHT - 26),
		Position = UDim2.new(0.73, 0, 0, 10),
		Text = ClientState.t("ui.sell") .. " " .. Economy.formatShort(Economy.sellPrice(record)),
		swatch = "wheat",
		icon = "lei",
		Parent = frame,
	}, function()
		Net.get("Sell"):FireServer(record.uid)
	end)
end

-- Ce e expus și ce e în beci, în ordinea afișării
local function entries(): { { record: any, displayed: boolean, key: string? } }
	local state = ClientState.state
	local list = {}
	local keys = {}
	for key in state.pedestals or {} do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)
	for _, key in keys do
		table.insert(list, { record = state.pedestals[key], displayed = true, key = key })
	end
	for _, record in state.cellar or {} do
		table.insert(list, { record = record, displayed = false, key = nil })
	end
	return list
end

local function signature(list: { { record: any, displayed: boolean, key: string? } }): string
	local parts = {}
	for _, entry in list do
		local r = entry.record
		table.insert(
			parts,
			string.format(
				"%s:%s:%s:%s:%s",
				tostring(r.uid),
				r.id,
				r.size,
				tostring(r.mutation),
				tostring(entry.key)
			)
		)
	end
	return table.concat(parts, "|")
end

-- Rândurile se refac doar când se schimbă creaturile (nu la fiecare leu primit)
local function render(force: boolean?)
	local list = entries()
	local sig = signature(list)
	if not force and sig == builtFor then
		return
	end
	builtFor = sig
	UI.clear(scroll)
	for order, entry in list do
		row(entry.record, order, entry.displayed, entry.key)
	end
end

function CellarPanel.toggle()
	UI.show(panel, not panel.Visible)
	if panel.Visible then
		render(true)
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
