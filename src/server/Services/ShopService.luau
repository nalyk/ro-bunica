--!strict
-- Taraba cu semințe. Stocul se reînnoiește pentru tot serverul la ore fixe;
-- fiecare jucător are cantitatea lui din stocul curent.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local GameState = require(Shared.GameState)
local Shop = require(Shared.Domain.Shop)
local RateLimiter = require(Shared.Domain.RateLimiter)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)
local EconomyService = require(script.Parent.EconomyService)
local Messenger = require(script.Parent.Messenger)

local ShopService = {}

local buyLimiter = RateLimiter.new(10, 5)
local serverStock: Shop.Stock = {}
local personalStock: { [Player]: Shop.Stock } = {}
local restockAt = 0

local function sendStock(player: Player)
	Net.get("Shop"):FireClient(player, personalStock[player] or {}, restockAt)
end

local function restock()
	serverStock = Shop.restock(math.random)
	restockAt = Shop.nextRestockAt(Workspace:GetServerTimeNow())
	GameState.set(GameState.Attributes.ShopRestockAt, restockAt)
	for _, player in Players:GetPlayers() do
		personalStock[player] = table.clone(serverStock)
		sendStock(player)
	end
end

local function onBuy(player: Player, seedId: unknown)
	if typeof(seedId) ~= "string" or not buyLimiter:allow(player.UserId, os.clock()) then
		return
	end
	local owner = PlotService.getOwner(player)
	local stock = personalStock[player]
	if not owner or not stock then
		return
	end
	local ok, result = Shop.checkPurchase(stock, seedId, owner.profile.lei)
	if not ok then
		Messenger.notify(player, "notify." .. tostring(result))
		return
	end
	stock[seedId] -= 1
	owner.profile.seeds[seedId] = (owner.profile.seeds[seedId] or 0) + 1
	EconomyService.addLei(owner, -(result :: number))
	StateService.markDirty(player)
	sendStock(player)
end

function ShopService.start()
	Net.get("BuySeed").OnServerEvent:Connect(onBuy)
	Net.get("ClientReady").OnServerEvent:Connect(function(player)
		if buyLimiter:allow(player.UserId, os.clock()) then
			sendStock(player)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		personalStock[player] = table.clone(serverStock)
		sendStock(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		personalStock[player] = nil
		buyLimiter:forget(player.UserId)
	end)
	restock()
	while true do
		task.wait(math.max(restockAt - Workspace:GetServerTimeNow(), 1))
		restock()
	end
end

return ShopService
