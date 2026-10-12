--!strict
-- Ogrăzile: generează satul, le dă jucătorilor și umple ogrăzile libere cu vecini NPC.
-- Un „Owner” e proprietarul unei ogrăzi, jucător sau NPC; restul serviciilor lucrează doar cu Owner.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DataTemplate = require(Shared.Config.DataTemplate)
local Creatures = require(Shared.Config.Creatures)
local Inventory = require(Shared.Domain.Inventory)
local Growth = require(Shared.Domain.Growth)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)
local DataService = require(script.Parent.DataService)

type Profile = DataTemplate.Profile

export type Plot = {
	index: number,
	geometry: WorldBuilder.PlotGeometry,
	owner: Owner?,
}

export type Owner = {
	kind: "Player" | "Npc",
	player: Player?,
	userId: number, -- negativ pentru NPC
	name: string,
	profile: Profile,
	plot: Plot,
	shieldUntil: number,
	joinedAt: number,
	removing: boolean?, -- true cât rulează callback-urile de plecare
}

local NPC_NAMES =
	{ "Moș Ion", "Tanti Maria", "Nea Petrică", "Baba Zenovia", "Vecinul Vasile", "Tanti Lida" }
local NPC_RESPAWN_SECONDS = 5
local NPC_REFILL_SECONDS = 60
local NPC_MIN_CREATURES = 3

local PlotService = {}

PlotService.plots = {} :: { Plot }

local ownersByPlayer: { [Player]: Owner } = {}
local addedCallbacks: { (Owner) -> () } = {}
local removingCallbacks: { (Owner) -> () } = {}
local npcCounter = 0

local function fire(list: { (Owner) -> () }, owner: Owner)
	for _, callback in list do
		local ok, err = pcall(callback :: any, owner)
		if not ok then
			warn("[PlotService] callback a eșuat:", err)
		end
	end
end

local function npcCreatureIds(): { string }
	local ids = {}
	for _, creature in Creatures.list do
		if creature.rarity == "Common" or creature.rarity == "Rare" then
			table.insert(ids, creature.id)
		end
	end
	return ids
end
local NPC_CREATURES = npcCreatureIds()

local function fillNpcProfile(owner: Owner)
	local profile = owner.profile
	local count = 0
	for _ in profile.pedestals do
		count += 1
	end
	while count < NPC_MIN_CREATURES do
		local id = NPC_CREATURES[math.random(1, #NPC_CREATURES)]
		local record = Inventory.newRecord(profile, owner.userId, id, Growth.rollSize(math.random), nil)
		if Inventory.place(profile, record) ~= "pedestal" then
			break
		end
		count += 1
	end
end

local function assign(plot: Plot, owner: Owner)
	plot.owner = owner
	plot.geometry.sign.Text = owner.name
	plot.geometry.model:SetAttribute("OwnerUserId", owner.userId)
	fire(addedCallbacks, owner)
end

local function vacate(plot: Plot)
	local owner = plot.owner
	if not owner then
		return
	end
	owner.removing = true
	fire(removingCallbacks, owner)
	plot.owner = nil
	plot.geometry.sign.Text = ""
	plot.geometry.model:SetAttribute("OwnerUserId", nil)
end

local function spawnNpc(plot: Plot)
	if plot.owner then
		return
	end
	npcCounter += 1
	local profile = DataTemplate.new()
	profile.pedestalCount = 8
	local owner: Owner = {
		kind = "Npc",
		player = nil,
		userId = -npcCounter,
		name = NPC_NAMES[(npcCounter - 1) % #NPC_NAMES + 1],
		profile = profile,
		plot = plot,
		shieldUntil = 0,
		joinedAt = os.clock(),
	}
	fillNpcProfile(owner)
	assign(plot, owner)
end

local function moveCharacterHome(player: Player, character: Model)
	local owner = ownersByPlayer[player]
	if not owner then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root then
		character:PivotTo(owner.plot.geometry.spawnCFrame)
	end
end

local function onProfileLoaded(player: Player, profile: Profile)
	-- Prima ogradă liberă; altfel una de NPC, pe care NPC-ul o eliberează
	local chosen: Plot? = nil
	for _, plot in PlotService.plots do
		if plot.owner == nil then
			chosen = plot
			break
		end
	end
	if not chosen then
		for _, plot in PlotService.plots do
			if plot.owner and plot.owner.kind == "Npc" then
				chosen = plot
				break
			end
		end
	end
	if not chosen then
		player:Kick("Serverul e plin.")
		return
	end
	vacate(chosen)
	local owner: Owner = {
		kind = "Player",
		player = player,
		userId = player.UserId,
		name = player.DisplayName,
		profile = profile,
		plot = chosen,
		shieldUntil = 0,
		joinedAt = os.clock(),
	}
	ownersByPlayer[player] = owner
	assign(chosen, owner)
	if player.Character then
		task.spawn(moveCharacterHome, player, player.Character)
	end
end

local function onProfileReleasing(player: Player)
	local owner = ownersByPlayer[player]
	if not owner then
		return
	end
	local plot = owner.plot
	vacate(plot)
	ownersByPlayer[player] = nil
	task.delay(NPC_RESPAWN_SECONDS, spawnNpc, plot)
end

function PlotService.init()
	for _, geometry in WorldBuilder.build() do
		table.insert(PlotService.plots, { index = geometry.index, geometry = geometry, owner = nil })
	end
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			moveCharacterHome(player, character)
		end)
	end)
end

function PlotService.start()
	DataService.onLoaded(onProfileLoaded)
	DataService.onReleasing(onProfileReleasing)
	for _, plot in PlotService.plots do
		spawnNpc(plot)
	end
	task.spawn(function()
		while true do
			task.wait(NPC_REFILL_SECONDS)
			for _, plot in PlotService.plots do
				local owner = plot.owner
				if owner and owner.kind == "Npc" then
					local before = owner.profile.uidCounter
					fillNpcProfile(owner)
					if owner.profile.uidCounter ~= before then
						PlotService.refresh(owner)
					end
				end
			end
		end
	end)
end

function PlotService.getOwner(player: Player): Owner?
	return ownersByPlayer[player]
end

function PlotService.owners(): { Owner }
	local list = {}
	for _, plot in PlotService.plots do
		if plot.owner then
			table.insert(list, plot.owner)
		end
	end
	return list
end

function PlotService.plotAt(position: Vector3): Plot?
	for _, plot in PlotService.plots do
		if WorldBuilder.contains(plot.geometry, position) then
			return plot
		end
	end
	return nil
end

function PlotService.onOwnerAdded(callback: (Owner) -> ())
	table.insert(addedCallbacks, callback)
	for _, plot in PlotService.plots do
		if plot.owner then
			task.spawn(callback, plot.owner)
		end
	end
end

function PlotService.onOwnerRemoving(callback: (Owner) -> ())
	table.insert(removingCallbacks, callback)
end

-- Cere redesenarea creaturilor unui proprietar (setat de CreatureService).
PlotService.refresh = function(_owner: Owner) end

return PlotService
