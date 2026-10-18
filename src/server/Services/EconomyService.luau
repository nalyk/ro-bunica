--!strict
-- Venitul pe secundă, bonusul de prieteni, venitul offline, vânzarea și mutarea creaturilor între piedestal și beci.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local EconomyConfig = require(Shared.Config.Economy)
local Economy = require(Shared.Domain.Economy)
local Inventory = require(Shared.Domain.Inventory)
local Raid = require(Shared.Domain.Raid)
local Rebirth = require(Shared.Domain.Rebirth)
local Collection = require(Shared.Domain.Collection)
local RateLimiter = require(Shared.Domain.RateLimiter)
local PlotService = require(script.Parent.PlotService)
local CreatureService = require(script.Parent.CreatureService)
local Analytics = require(script.Parent.Parent.Analytics)
local Progress = require(script.Parent.Parent.Progress)
local Badges = require(script.Parent.Parent.Badges)
local StateService = require(script.Parent.StateService)
local RaidService = require(script.Parent.RaidService)
local Messenger = require(script.Parent.Messenger)
local Friends = require(script.Parent.Parent.Social.Friends)

type Owner = PlotService.Owner

local EconomyService = {}

local actionLimiter = RateLimiter.new(8, 4)
local friendCounts: { [Player]: number } = {}
local leaderstatsLei: { [Player]: IntValue } = {}
local leaderstatsDefends: { [Player]: IntValue } = {}

local function areFriends(a: Player, b: Player): boolean
	return Friends.areFriends(a, b)
end

local function recountFriends()
	for _, player in Players:GetPlayers() do
		local count = 0
		for _, other in Players:GetPlayers() do
			if other ~= player and areFriends(player, other) then
				count += 1
			end
		end
		friendCounts[player] = count
	end
end

-- Multiplicatori în plus pe venit (permisul 2× lei), puși de MonetizationService
local boosts: { [Player]: number? } = {}

function EconomyService.setBoost(player: Player, factor: number?)
	boosts[player] = factor
	StateService.markDirty(player)
end

-- Toți multiplicatorii de venit: prieteni, permisul 2× lei, renașterile și pragurile colecției.
function EconomyService.multiplier(player: Player): number
	local owner = PlotService.getOwner(player)
	local progress = if owner
		then Rebirth.multiplier(owner.profile.rebirths) * Collection.multiplier(owner.profile)
		else 1
	return Economy.friendMultiplier(friendCounts[player] or 0) * (boosts[player] or 1) * progress
end

function EconomyService.addLei(owner: Owner, amount: number)
	owner.profile.lei = math.max(owner.profile.lei + amount, 0)
	local player = owner.player
	if player then
		local stat = leaderstatsLei[player]
		if stat then
			stat.Value = math.floor(math.min(owner.profile.lei, 2 ^ 53))
		end
		StateService.markDirty(player)
		Badges.forLei(player, owner.profile.lei)
	end
end

local function setupLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local lei = Instance.new("IntValue")
	lei.Name = "Lei"
	lei.Parent = folder
	-- Câte apărări cu papucul: clasamentul apărătorilor, vizibil tuturor
	local defends = Instance.new("IntValue")
	defends.Name = "Papuci"
	defends.Parent = folder
	folder.Parent = player
	leaderstatsLei[player] = lei
	leaderstatsDefends[player] = defends
end

local function grantOffline(owner: Owner)
	local profile = owner.profile
	if profile.lastSeen <= 0 then
		return
	end
	local earned =
		Economy.offlineEarnings(Economy.totalIncome(profile.pedestals, 1), os.time() - profile.lastSeen)
	if earned > 0 then
		EconomyService.addLei(owner, earned)
		Analytics.source(owner.player, owner.profile, earned, "Offline")
		Messenger.notify(owner.player, "notify.Offline", { Economy.formatShort(earned) })
	end
end

local function guard(player: Player): Owner?
	if not actionLimiter:allow(player.UserId, os.clock()) then
		return nil
	end
	return PlotService.getOwner(player)
end

-- O creatură pusă la bazar (marcată `listed`) nu se vinde și nu se mută până nu e retrasă
local function isListed(owner: any, uid: string): boolean
	local index = Inventory.findCellar(owner.profile, uid)
	local record = index and owner.profile.cellar[index]
	return record ~= nil and (record :: any).listed ~= nil
end

local function onSell(player: Player, uid: unknown)
	local owner = guard(player)
	if not owner or typeof(uid) ~= "string" or RaidService.isCarried(uid) then
		return
	end
	if isListed(owner, uid) then
		Messenger.notify(player, "notify.Listed")
		return
	end
	local key = Inventory.findPedestal(owner.profile, uid)
	local record = Inventory.remove(owner.profile, uid)
	if not record then
		return
	end
	local price = Economy.sellPrice(record)
	if key then
		CreatureService.renderKey(owner, key)
		CreatureService.refreshShowcase(owner)
	end
	EconomyService.addLei(owner, price)
	Analytics.source(player, owner.profile, price, "Sell", record.id)
	Messenger.notify(player, "notify.Sold", { Economy.formatShort(price) })
	Progress.emit(owner, "sell")
end

local function onMoveToCellar(player: Player, key: unknown)
	local owner = guard(player)
	if not owner or typeof(key) ~= "string" then
		return
	end
	local record = owner.profile.pedestals[key]
	if not record or RaidService.isCarried(record.uid) then
		return
	end
	if Inventory.moveToCellar(owner.profile, key) then
		CreatureService.renderKey(owner, key)
		CreatureService.refreshShowcase(owner)
		StateService.markDirty(player)
	else
		Messenger.notify(player, "notify.Full")
	end
end

local function onMoveToPedestal(player: Player, uid: unknown)
	local owner = guard(player)
	if not owner or typeof(uid) ~= "string" then
		return
	end
	if isListed(owner, uid) then
		Messenger.notify(player, "notify.Listed")
		return
	end
	local key = Inventory.moveToPedestal(owner.profile, uid, nil)
	if key then
		CreatureService.renderKey(owner, key)
		CreatureService.refreshShowcase(owner)
		StateService.markDirty(player)
	else
		Messenger.notify(player, "notify.Full")
	end
end

-- Venitul pe secundă se adună și se măsoară o dată pe minut (nu la fiecare tic)
local pendingIncome: { [Player]: number } = {}
local INCOME_FLUSH_SECONDS = 60

local function flushIncome(player: Player)
	local amount = pendingIncome[player]
	local owner = PlotService.getOwner(player)
	pendingIncome[player] = nil
	if amount and owner then
		Analytics.source(player, owner.profile, amount, "Income")
	end
end

local function incomeTick(dt: number)
	for _, owner in PlotService.owners() do
		local player = owner.player
		if owner.kind == "Player" and player then
			owner.profile.playSeconds += dt
			local income = Economy.totalIncome(owner.profile.pedestals, EconomyService.multiplier(player))
			if income > 0 then
				EconomyService.addLei(owner, income * dt)
				pendingIncome[player] = (pendingIncome[player] or 0) + income * dt
			end
		end
	end
end

function EconomyService.start()
	task.spawn(function()
		while true do
			task.wait(INCOME_FLUSH_SECONDS)
			for player in pendingIncome do
				flushIncome(player)
			end
		end
	end)
	Net.get("Sell").OnServerEvent:Connect(onSell)
	Net.get("MoveToCellar").OnServerEvent:Connect(onMoveToCellar)
	Net.get("MoveToPedestal").OnServerEvent:Connect(onMoveToPedestal)

	Players.PlayerAdded:Connect(function(player)
		setupLeaderstats(player)
		task.spawn(recountFriends)
	end)
	for _, player in Players:GetPlayers() do
		setupLeaderstats(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		friendCounts[player] = nil
		leaderstatsLei[player] = nil
		flushIncome(player)
		leaderstatsDefends[player] = nil
		boosts[player] = nil
		actionLimiter:forget(player.UserId)
	end)
	PlotService.onOwnerAdded(function(owner)
		if owner.kind == "Player" then
			grantOffline(owner)
			EconomyService.addLei(owner, 0) -- sincronizează leaderstats
			local player = owner.player :: Player
			if leaderstatsDefends[player] then
				leaderstatsDefends[player].Value = owner.profile.stats.defends
			end
		end
	end)

	-- Apărarea e răsplătită: cine salvează o creatură primește o parte din prețul ei
	RaidService.onActorHit(function(_victim, source)
		local thrower = source.thrower
		local throwerOwner = if thrower then PlotService.getOwnerOfActor(thrower) else nil
		if not throwerOwner then
			return
		end
		local saved = source.saved
		if saved then
			local reward = Raid.defenseReward(Economy.sellPrice(saved))
			if reward > 0 then
				EconomyService.addLei(throwerOwner, reward)
				Analytics.source(thrower and thrower.player, throwerOwner.profile, reward, "DefenseReward")
				Messenger.notify(
					thrower and thrower.player,
					"notify.DefenseReward",
					{ Economy.formatShort(reward) }
				)
			end
		end
		local player = throwerOwner.player
		if player and leaderstatsDefends[player] then
			leaderstatsDefends[player].Value = throwerOwner.profile.stats.defends
		end
	end)

	while true do
		local dt = task.wait(EconomyConfig.incomeTickSeconds)
		local ok, err = pcall(incomeTick :: any, dt)
		if not ok then
			warn("[EconomyService] tick a eșuat:", err)
		end
	end
end

return EconomyService
