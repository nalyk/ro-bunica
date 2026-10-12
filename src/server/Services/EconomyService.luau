--!strict
-- Venitul pe secundă, bonusul de prieteni, venitul offline, vânzarea și mutarea creaturilor între piedestal și beci.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local EconomyConfig = require(Shared.Config.Economy)
local Economy = require(Shared.Domain.Economy)
local Inventory = require(Shared.Domain.Inventory)
local RateLimiter = require(Shared.Domain.RateLimiter)
local PlotService = require(script.Parent.PlotService)
local CreatureService = require(script.Parent.CreatureService)
local StateService = require(script.Parent.StateService)
local RaidService = require(script.Parent.RaidService)
local Messenger = require(script.Parent.Messenger)
local Friends = require(script.Parent.Parent.Social.Friends)

type Owner = PlotService.Owner

local EconomyService = {}

local actionLimiter = RateLimiter.new(8, 4)
local friendCounts: { [Player]: number } = {}
local leaderstatsLei: { [Player]: IntValue } = {}

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

function EconomyService.multiplier(player: Player): number
	return Economy.friendMultiplier(friendCounts[player] or 0)
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
	end
end

local function setupLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local lei = Instance.new("IntValue")
	lei.Name = "Lei"
	lei.Parent = folder
	folder.Parent = player
	leaderstatsLei[player] = lei
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
		Messenger.notify(owner.player, "notify.Offline", { Economy.formatShort(earned) })
	end
end

local function guard(player: Player): Owner?
	if not actionLimiter:allow(player.UserId, os.clock()) then
		return nil
	end
	return PlotService.getOwner(player)
end

local function onSell(player: Player, uid: unknown)
	local owner = guard(player)
	if not owner or typeof(uid) ~= "string" or RaidService.isCarried(uid) then
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
	Messenger.notify(player, "notify.Sold", { Economy.formatShort(price) })
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
	local key = Inventory.moveToPedestal(owner.profile, uid, nil)
	if key then
		CreatureService.renderKey(owner, key)
		CreatureService.refreshShowcase(owner)
		StateService.markDirty(player)
	else
		Messenger.notify(player, "notify.Full")
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
			end
		end
	end
end

function EconomyService.start()
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
		actionLimiter:forget(player.UserId)
	end)
	PlotService.onOwnerAdded(function(owner)
		if owner.kind == "Player" then
			grantOffline(owner)
			EconomyService.addLei(owner, 0) -- sincronizează leaderstats
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
