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
local Actors = require(script.Parent.Parent.Actors)

type Profile = DataTemplate.Profile

export type Plot = {
	index: number,
	geometry: WorldBuilder.PlotGeometry,
	owner: Owner?,
}

export type Owner = {
	kind: "Player" | "Npc",
	player: Player?,
	actor: Actors.Actor?, -- cine apără ograda: jucătorul, un bot sau nimeni (vecin NPC simplu)
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
		actor = nil,
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

-- Mută personajul acasă. Roblox poate repoziționa personajul imediat după CharacterAdded,
-- deci verificăm după o secundă și reîncercăm (playtest: jucătorul rămăsese la spawn-ul satului).
local function debugLog(message: string)
	if game:GetService("RunService"):IsStudio() then
		print("[Plot] " .. message)
	end
end

local function moveCharacterHome(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root then
		return
	end
	for attempt = 1, 3 do
		local owner = ownersByPlayer[player]
		if not owner or character.Parent == nil then
			debugLog(
				string.format("acasă %s: fără ogradă sau personaj (încercarea %d)", player.Name, attempt)
			)
			return
		end
		task.wait(0.2)
		local home = owner.plot.geometry.spawnCFrame
		character:PivotTo(home)
		task.wait(1)
		local distance = (root.Position - home.Position).Magnitude
		debugLog(
			string.format("acasă %s: încercarea %d, la %.0f studs de casă", player.Name, attempt, distance)
		)
		if distance < 20 then
			return
		end
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
		actor = Actors.forPlayer(player),
		userId = player.UserId,
		name = player.DisplayName,
		profile = profile,
		plot = chosen,
		shieldUntil = 0,
		joinedAt = os.clock(),
	}
	ownersByPlayer[player] = owner
	player.RespawnLocation = chosen.geometry.spawn
	assign(chosen, owner)
	debugLog("profil încărcat " .. player.Name .. ", personaj: " .. tostring(player.Character ~= nil))
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
	-- Și pentru jucătorii intrați înainte de pornirea serverului (Play Solo, primul jucător pe un server nou)
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			moveCharacterHome(player, character)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

function PlotService.start()
	DataService.onLoaded(onProfileLoaded)
	DataService.onReleasing(onProfileReleasing)
	-- Un bot care dispare își eliberează ograda, iar vecinul NPC revine
	Actors.onRemoving(function(actor)
		if actor.player then
			return
		end
		for _, plot in PlotService.plots do
			if plot.owner and plot.owner.actor == actor then
				vacate(plot)
				spawnNpc(plot)
			end
		end
	end)
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

-- Ograda unui actor (jucător sau bot), dacă are una.
function PlotService.getOwnerOfActor(actor: Actors.Actor): Owner?
	if actor.player then
		return ownersByPlayer[actor.player]
	end
	for _, plot in PlotService.plots do
		if plot.owner and plot.owner.actor == actor then
			return plot.owner
		end
	end
	return nil
end

-- Dă unui bot o ogradă de vecin (tutorial, teste e2e). Botul poate apoi fura și depune.
function PlotService.assignBot(plot: Plot, actor: Actors.Actor): Owner
	vacate(plot)
	local profile = DataTemplate.new()
	local owner: Owner = {
		kind = "Npc",
		player = nil,
		actor = actor,
		userId = actor.id,
		name = actor.name,
		profile = profile,
		plot = plot,
		shieldUntil = 0,
		joinedAt = os.clock(),
	}
	assign(plot, owner)
	return owner
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
