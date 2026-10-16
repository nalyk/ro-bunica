--!strict
-- Straturile: plantare, creștere, eclozare. Vizualul plantelor se randează pe client din atributele stratului.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Sizes = require(Shared.Config.Sizes)
local Mutations = require(Shared.Config.Mutations)
local EconomyConfig = require(Shared.Config.Economy)
local Growth = require(Shared.Domain.Growth)
local Inventory = require(Shared.Domain.Inventory)
local RateLimiter = require(Shared.Domain.RateLimiter)
local PlotService = require(script.Parent.PlotService)
local CreatureService = require(script.Parent.CreatureService)
local Badges = require(script.Parent.Parent.Badges)
local Analytics = require(script.Parent.Parent.Analytics)
local StateService = require(script.Parent.StateService)
local WeatherService = require(script.Parent.WeatherService)
local Messenger = require(script.Parent.Messenger)
local ArtFade = require(script.Parent.Parent.World.ArtFade)

type Owner = PlotService.Owner

local TICK_SECONDS = 1
local PLANT_MAX_DISTANCE = 25
local STARTER_SECONDS_LEFT = 15

local GardenService = {}

local plantLimiter = RateLimiter.new(6, 3)
local fullWarned: { [Owner]: boolean } = {}

local function updateBedVisual(owner: Owner, key: string)
	local bed = owner.plot.geometry.beds[key]
	if not bed then
		return
	end
	local plant = owner.profile.beds[key]
	bed:SetAttribute("SeedId", if plant then plant.seedId else nil)
	bed:SetAttribute("Size", if plant then plant.size else nil)
	bed:SetAttribute("Mutation", if plant then plant.mutation else nil)
	bed:SetAttribute("Progress", if plant then Growth.progress(plant) else nil)
end

local function renderBeds(owner: Owner)
	for key, bed in owner.plot.geometry.beds do
		ArtFade.set(bed, if (tonumber(key) or 0) <= owner.profile.bedCount then 0 else 0.7)
		updateBedVisual(owner, key)
	end
end

local function clearBeds(owner: Owner)
	for _, bed in owner.plot.geometry.beds do
		for _, attribute in { "SeedId", "Size", "Mutation", "Progress" } do
			bed:SetAttribute(attribute, nil)
		end
	end
end

local function announceHatch(owner: Owner, record: { id: string, size: string, mutation: string? })
	local creature = Creatures.byId[record.id]
	local rarity = Rarities.byId[creature.rarity]
	local size = Sizes.byId[record.size]
	local mutation = if record.mutation then Mutations.byId[record.mutation] else nil
	if rarity.announceHatch or (size and size.announce) or (mutation and mutation.announce) then
		Messenger.announce("announce.Hatch", { owner.name, Messenger.key("creature." .. record.id) })
	end
end

local function hatch(owner: Owner, key: string): boolean
	local profile = owner.profile
	local plant = profile.beds[key]
	local record = Inventory.newRecord(profile, owner.userId, plant.seedId, plant.size, plant.mutation)
	local where, pedestalKey = Inventory.place(profile, record)
	if where == nil then
		profile.uidCounter -= 1 -- n-a fost folosit
		if not fullWarned[owner] then
			fullWarned[owner] = true
			Messenger.notify(owner.player, "notify.Full")
		end
		return false
	end
	fullWarned[owner] = nil
	profile.beds[key] = nil
	profile.stats.hatched += 1
	Analytics.step(owner.player, profile, "StarterHatched")
	Badges.award(owner.player, "hatch")
	Badges.forRarity(owner.player, Creatures.byId[record.id].rarity)
	if where == "pedestal" and pedestalKey then
		CreatureService.renderKey(owner, pedestalKey)
		CreatureService.refreshShowcase(owner)
	end
	Messenger.notify(owner.player, "notify.Hatched", { Messenger.key("creature." .. record.id) })
	announceHatch(owner, record)
	return true
end

local function tick(dt: number)
	local speed = WeatherService.growthSpeed()
	for _, owner in PlotService.owners() do
		if owner.kind ~= "Player" then
			continue
		end
		local changed = false
		for key, plant in owner.profile.beds do
			if Growth.isReady(plant) or Growth.advance(plant, dt, speed) then
				if hatch(owner, key) then
					changed = true
				end
			end
			updateBedVisual(owner, key)
		end
		if changed then
			StateService.markDirty(owner.player)
		end
	end
end

local function onPlant(player: Player, bedKey: unknown, seedId: unknown)
	if typeof(bedKey) ~= "string" or typeof(seedId) ~= "string" then
		return
	end
	if not plantLimiter:allow(player.UserId, os.clock()) then
		return
	end
	local owner = PlotService.getOwner(player)
	if not owner then
		return
	end
	local profile = owner.profile
	local index = tonumber(bedKey)
	if not index or index < 1 or index > profile.bedCount or profile.beds[bedKey] ~= nil then
		return
	end
	if (profile.seeds[seedId] or 0) < 1 or not Creatures.byId[seedId] then
		return
	end
	local bed = owner.plot.geometry.beds[bedKey]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not bed or not root or (root.Position - bed.Position).Magnitude > PLANT_MAX_DISTANCE then
		return
	end
	profile.seeds[seedId] -= 1
	if profile.seeds[seedId] <= 0 then
		profile.seeds[seedId] = nil
	end
	profile.beds[bedKey] = Growth.newPlant(seedId, math.random)
	Analytics.step(player, profile, "FirstPlanted")
	updateBedVisual(owner, bedKey)
	StateService.markDirty(player)
end

-- Prima intrare: o sămânță deja plantată, care eclozează în câteva secunde.
local function giveStarter(owner: Owner)
	local profile = owner.profile
	if profile.tutorialDone or next(profile.beds) or next(profile.pedestals) or #profile.cellar > 0 then
		return
	end
	local plant = Growth.newPlant(Creatures.starterSeed, math.random)
	plant.size = Sizes.default
	plant.grown = math.max(Growth.requiredSeconds(plant) - STARTER_SECONDS_LEFT, 0)
	profile.beds["1"] = plant
	profile.tutorialDone = true
end

-- Folosit de vreme: aplică o funcție pe fiecare plantă în creștere.
-- Îngrășământul: toate plantele din ogradă termină de crescut acum (ecloziunea vine la următorul pas)
function GardenService.fertilize(owner: Owner): number
	local count = 0
	for _, plant in owner.profile.beds do
		local required = Growth.requiredSeconds(plant)
		if required < math.huge and plant.grown < required then
			plant.grown = required
			count += 1
		end
	end
	renderBeds(owner)
	StateService.markDirty(owner.player)
	return count
end

-- Redesenează straturile (după o îmbunătățire care deblochează straturi)
function GardenService.refreshBeds(owner: Owner)
	renderBeds(owner)
end

function GardenService.forEachPlant(callback: (Owner, string, Growth.Plant) -> ())
	for _, owner in PlotService.owners() do
		if owner.kind == "Player" then
			for key, plant in owner.profile.beds do
				callback(owner, key, plant)
			end
		end
	end
end

GardenService.updateBedVisual = updateBedVisual

function GardenService.start()
	Net.get("Plant").OnServerEvent:Connect(onPlant)
	PlotService.onOwnerAdded(function(owner)
		if owner.kind == "Player" then
			-- Plantele au crescut și cât a lipsit (plafonat); cele gata eclozează la următorul tick
			local profile = owner.profile
			if profile.lastSeen > 0 then
				local away = os.time() - profile.lastSeen
				for _, plant in profile.beds do
					Growth.advanceOffline(plant, away, EconomyConfig.offlineCapSeconds)
				end
			end
			giveStarter(owner)
		end
		renderBeds(owner)
	end)
	PlotService.onOwnerRemoving(function(owner)
		clearBeds(owner)
		fullWarned[owner] = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		plantLimiter:forget(player.UserId)
	end)
	task.spawn(function()
		while true do
			local dt = task.wait(TICK_SECONDS)
			local ok, err = pcall(tick :: any, dt)
			if not ok then
				warn("[GardenService] tick a eșuat:", err)
			end
		end
	end)
end

return GardenService
