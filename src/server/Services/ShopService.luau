--!strict
-- Taraba cu semințe. Stocul se reînnoiește pentru tot serverul la ore fixe;
-- fiecare jucător are cantitatea lui din stocul curent.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local GameState = require(Shared.GameState)
local Shop = require(Shared.Domain.Shop)
local Creatures = require(Shared.Config.Creatures)
local RateLimiter = require(Shared.Domain.RateLimiter)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)
local Analytics = require(script.Parent.Parent.Analytics)
local EconomyService = require(script.Parent.EconomyService)
local Messenger = require(script.Parent.Messenger)
local Progress = require(script.Parent.Parent.Progress)

local ShopService = {}

local buyLimiter = RateLimiter.new(10, 5)
local serverStock: Shop.Stock = {}
local personalStock: { [Player]: Shop.Stock } = {}
local restockAt = 0
local exclusive: string? = nil -- sămânța exclusivă a evenimentului în curs (una pe jucător)
local boughtExclusive: { [Player]: boolean } = {}

local function addExclusive(player: Player)
	local stock = personalStock[player]
	if exclusive and stock and not boughtExclusive[player] then
		stock[exclusive] = 1
	end
end

local function sendStock(player: Player)
	Net.get("Shop"):FireClient(player, personalStock[player] or {}, restockAt)
end

local function restock()
	serverStock = Shop.restock(math.random)
	restockAt = Shop.nextRestockAt(Workspace:GetServerTimeNow())
	GameState.set(GameState.Attributes.ShopRestockAt, restockAt)
	for _, player in Players:GetPlayers() do
		personalStock[player] = table.clone(serverStock)
		addExclusive(player)
		sendStock(player)
	end
end

function ShopService.exclusive(): string?
	return exclusive
end

-- Pornește sau oprește exclusivitatea de eveniment (doar online, cât ține evenimentul).
function ShopService.setExclusive(seedId: string?)
	exclusive = seedId
	table.clear(boughtExclusive)
	for _, player in Players:GetPlayers() do
		local stock = personalStock[player]
		if stock then
			for id in stock do
				if Creatures.byId[id] and Creatures.byId[id].exclusive then
					stock[id] = nil
				end
			end
			addExclusive(player)
			sendStock(player)
		end
	end
end

-- „Semințe proaspete” (produs pe Robux): taraba jucătorului se umple acum, fără să aștepte reînnoirea serverului
function ShopService.restockFor(player: Player)
	local stock = personalStock[player]
	if not stock then
		return
	end
	personalStock[player] = Shop.merge(stock, Shop.restock(math.random))
	addExclusive(player)
	sendStock(player)
end

-- O sămânță la un preț special (negustorul de la rutieră, trenul). Întoarce true dacă s-a vândut.
function ShopService.offer(owner: PlotService.Owner, seedId: string, price: number): boolean
	if not Creatures.byId[seedId] or owner.profile.lei < price then
		if owner.player then
			Messenger.notify(owner.player, "notify.NotEnoughLei")
		end
		return false
	end
	owner.profile.seeds[seedId] = (owner.profile.seeds[seedId] or 0) + 1
	EconomyService.addLei(owner, -price)
	Analytics.sink(owner.player, owner.profile, price, "Merchant", seedId)
	StateService.markDirty(owner.player)
	return true
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
	if seedId == exclusive then
		boughtExclusive[player] = true
	end
	owner.profile.seeds[seedId] = (owner.profile.seeds[seedId] or 0) + 1
	EconomyService.addLei(owner, -(result :: number))
	Analytics.sink(player, owner.profile, result :: number, "Shop", seedId)
	Analytics.step(player, owner.profile, "FirstSeedBought")
	Progress.emit(owner, "buySeed")
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
		addExclusive(player)
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
