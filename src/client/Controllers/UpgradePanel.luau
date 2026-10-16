--!strict
-- Panoul „Ograda”: îmbunătățirile pe lei (piedestale, straturi, beci, papuci, Grivei, Bunica mai ageră).
-- Rândurile se construiesc o dată; la fiecare stare nouă se actualizează nivelul, prețul și culoarea butonului.
-- Prețul vine din aceeași logică pe care o verifică serverul (Domain/Upgrades).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local UpgradesConfig = require(Shared.Config.Upgrades)
local Upgrades = require(Shared.Domain.Upgrades)
local Economy = require(Shared.Domain.Economy)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)

local UpgradePanel = {}

local ROW_HEIGHT = 84

local panel: Frame
local scroll: ScrollingFrame

type Row = { id: string, level: TextLabel, buy: TextButton }
local rows: { Row } = {}

-- Profilul văzut de client, în forma pe care o cere Domain/Upgrades
local function profileView(): any
	local state = ClientState.state
	return {
		lei = state.lei or 0,
		upgrades = state.upgrades or {},
		pedestalCount = state.pedestalCount or 0,
		bedCount = state.bedCount or 0,
		cellarCapacity = state.cellarCapacity or 0,
	}
end

local function refresh()
	local profile = profileView()
	for _, row in rows do
		local def = UpgradesConfig.byId[row.id]
		local level = Upgrades.level(profile, row.id)
		row.level.Text = ClientState.t("ui.level", { level, def.maxLevel })
		local cost = Upgrades.nextCost(profile, row.id)
		if cost then
			UI.setText(row.buy, Economy.formatShort(cost) .. " " .. ClientState.t("ui.lei"))
			UI.setSwatch(row.buy, if profile.lei >= cost then "vine" else "stone")
		else
			UI.setText(row.buy, ClientState.t("ui.maxed"))
			UI.setSwatch(row.buy, "wheat")
		end
	end
end

local function build()
	UI.clear(scroll)
	table.clear(rows)
	for order, def in UpgradesConfig.list do
		local row =
			UI.frame({ Size = UDim2.new(1, -12, 0, ROW_HEIGHT), LayoutOrder = order, Parent = scroll })
		local badge = UI.frame({
			Size = UDim2.fromOffset(ROW_HEIGHT - 16, ROW_HEIGHT - 16),
			Position = UDim2.fromOffset(8, 8),
			BackgroundColor3 = Theme.swatches.wheat.light,
			Parent = row,
		})
		local corner = badge:FindFirstChildWhichIsA("UICorner") or Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = badge
		local icon =
			UI.icon(def.icon, { Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1) })
		if icon then
			icon.Parent = badge
		end
		UI.capText(
			UI.label({
				Size = UDim2.new(0.5, -(ROW_HEIGHT + 4), 0.36, 0),
				Position = UDim2.new(0, ROW_HEIGHT + 2, 0.08, 0),
				Text = ClientState.t("upgrade." .. def.id),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			}),
			19
		)
		UI.capText(
			UI.label({
				Size = UDim2.new(0.5, -(ROW_HEIGHT + 4), 0.28, 0),
				Position = UDim2.new(0, ROW_HEIGHT + 2, 0.44, 0),
				Text = ClientState.t("upgrade." .. def.id .. ".desc"),
				TextColor3 = Theme.inkSoft,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			}),
			15
		)
		local level = UI.capText(
			UI.label({
				Size = UDim2.new(0.5, -(ROW_HEIGHT + 4), 0.22, 0),
				Position = UDim2.new(0, ROW_HEIGHT + 2, 0.72, 0),
				Text = "",
				TextColor3 = Theme.swatches.ie.dark,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			}),
			14
		)
		local buy = UI.button({
			Size = UDim2.new(0.32, -10, 0, ROW_HEIGHT - 26),
			Position = UDim2.new(0.66, 0, 0, 10),
			Text = "…", -- eticheta trebuie să existe ca refresh() s-o poată schimba
			swatch = "stone",
			icon = "lei",
			Parent = row,
		}, function()
			Net.get("BuyUpgrade"):FireServer(def.id)
		end)
		table.insert(rows, { id = def.id, level = level, buy = buy })
	end
	refresh()
end

function UpgradePanel.toggle()
	UI.show(panel, not panel.Visible)
	if panel.Visible then
		refresh()
	end
end

function UpgradePanel.start()
	panel, scroll = UI.panel(ClientState.t("ui.upgrades"), function()
		UI.show(panel, false)
	end)
	build()
	ClientState.onChanged(function()
		if panel.Visible then
			refresh()
		end
	end)
end

return UpgradePanel
