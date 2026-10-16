--!strict
-- Panoul tarabei cu semințe.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Economy = require(Shared.Domain.Economy)
local ClientState = require(script.Parent.ClientState)
local UI = require(script.Parent.UI)

local ShopPanel = {}

local panel: Frame
local scroll: ScrollingFrame
local restockLabel: TextLabel

local function render()
	UI.clear(scroll)
	local lei = ClientState.state.lei or 0
	for order, creature in Creatures.list do
		local stock = ClientState.shopStock[creature.id]
		if not creature.seedPrice or not stock then
			continue
		end
		local rarity = Rarities.byId[creature.rarity]
		local row = UI.frame({ Size = UDim2.new(1, -12, 0, 56), LayoutOrder = order, Parent = scroll })
		UI.label({
			Size = UDim2.new(0.5, -10, 0.6, 0),
			Position = UDim2.fromOffset(10, 2),
			Text = ClientState.t("creature." .. creature.id),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		UI.label({
			Size = UDim2.new(0.5, -10, 0.35, 0),
			Position = UDim2.new(0, 10, 0.6, 0),
			Text = ClientState.t("rarity." .. creature.rarity)
				.. " · "
				.. ClientState.t("ui.perSecond", { Economy.formatShort(creature.income) }),
			TextColor3 = rarity.color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		UI.label({
			Size = UDim2.new(0.15, 0, 1, -8),
			Position = UDim2.new(0.5, 0, 0, 4),
			Text = ClientState.t("ui.stock", { stock }),
			Parent = row,
		})
		local affordable = lei >= creature.seedPrice and stock > 0
		UI.button({
			Size = UDim2.new(0.3, -10, 1, -12),
			Position = UDim2.new(0.68, 0, 0, 6),
			Text = Economy.formatShort(creature.seedPrice) .. " " .. ClientState.t("ui.lei"),
			BackgroundColor3 = if affordable then UI.colors.green else Color3.fromRGB(150, 150, 150),
			Parent = row,
		}, function()
			Net.get("BuySeed"):FireServer(creature.id)
		end)
	end
end

function ShopPanel.toggle()
	UI.show(panel, not panel.Visible)
	if panel.Visible then
		render()
	end
end

function ShopPanel.start()
	panel, scroll = UI.panel(ClientState.t("ui.shop"), function()
		UI.show(panel, false)
	end)
	restockLabel = UI.label({
		Size = UDim2.new(0.4, 0, 0, 24),
		Position = UDim2.new(0.55, 0, 0, 14),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = panel,
	})
	ClientState.onShopChanged(function()
		if panel.Visible then
			render()
		end
	end)
	ClientState.onChanged(function()
		if panel.Visible then
			render()
		end
	end)
	task.spawn(function()
		while true do
			local left = ClientState.shopRestockAt - Workspace:GetServerTimeNow()
			restockLabel.Text = ClientState.t("ui.restockIn", { UI.formatTime(left) })
			task.wait(1)
		end
	end)
end

return ShopPanel
