--!strict
-- Pescuitul la iaz (Domain/Fishing, Config/Fish), activitate permanentă: arunci undița de pe mal sau de pe
-- debarcader, aștepți tremurul (2–8 s), apoi tragi ținând tensiunea în zona bună. Clientul trage și trimite
-- apăsările pe pași de 0,1 s; serverul refă tragerea cu aceleași smucituri (seed) și decide. Peștele prins
-- intră în colecție (de vândut sau hrană); oul de creatură dă o sămânță rară.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local GameState = require(Shared.GameState)
local Fish = require(Shared.Config.Fish)
local Creatures = require(Shared.Config.Creatures)
local Fishing = require(Shared.Domain.Fishing)
local VillageLayout = require(Shared.Domain.VillageLayout)
local RateLimiter = require(Shared.Domain.RateLimiter)
local Actors = require(script.Parent.Parent.Actors)
local Busy = require(script.Parent.Parent.Busy)
local Records = require(script.Parent.Parent.Records)
local PlotService = require(script.Parent.PlotService)
local RaidService = require(script.Parent.RaidService)
local EconomyService = require(script.Parent.EconomyService)
local StateService = require(script.Parent.StateService)
local Messenger = require(script.Parent.Messenger)
local Analytics = require(script.Parent.Parent.Analytics)

type Owner = PlotService.Owner
type Cast = { biteAt: number, seed: number, bitten: boolean }

local FishingService = {}

local casts: { [Owner]: Cast } = {}
local limiter = RateLimiter.new(6, 1)
local pond = VillageLayout.build().sites.iaz.Position
local rng = Random.new()

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function tell(owner: Owner, payload: { [string]: any })
	if owner.player then
		Net.get("Fishing"):FireClient(owner.player, payload)
	end
end

function FishingService.season(): string
	local season = GameState.get(GameState.Attributes.Season)
	return if typeof(season) == "string" and season ~= "" then season else "Vara"
end

function FishingService.weather(): string
	local weather = GameState.get(GameState.Attributes.Weather)
	return if typeof(weather) == "string" then weather else ""
end

-- Arunci undița (lângă iaz, nu în mini-joc, nu cu o creatură furată în brațe)
function FishingService.cast(owner: Owner): boolean
	local actor = owner.actor
	local root = actor and Actors.root(actor)
	if not actor or not root or Busy.is(actor) or RaidService.isCarrying(actor) or casts[owner] then
		return false
	end
	if Vector3.new(root.Position.X - pond.X, 0, root.Position.Z - pond.Z).Magnitude > Fish.castDistance then
		Messenger.notify(owner.player, "fishing.far")
		return false
	end
	local biteAt = now() + rng:NextNumber(Fish.biteMin, Fish.biteMax)
	local cast = { biteAt = biteAt, seed = rng:NextInteger(1, 2 ^ 30), bitten = false }
	casts[owner] = cast
	tell(owner, { state = "waiting", biteAt = biteAt })
	task.delay(biteAt - now(), function()
		if casts[owner] == cast then
			cast.bitten = true
			tell(owner, { state = "bite", seed = cast.seed, window = Fish.biteWindow })
		end
	end)
	return true
end

-- Pentru teste: tremurul acum
function FishingService.biteNow(owner: Owner): number?
	local cast = casts[owner]
	if not cast then
		return nil
	end
	cast.biteAt = now()
	cast.bitten = true
	return cast.seed
end

-- Rezultatul tragerii (apăsările pe pași). Întoarce peștele prins sau nil.
function FishingService.reel(owner: Owner, inputs: { boolean }): string?
	local cast = casts[owner]
	casts[owner] = nil
	if not cast or not cast.bitten or #inputs == 0 or #inputs > Fish.maxSteps then
		return nil
	end
	-- trebuie să fi început să tragi în fereastra tremurului (și nu mai repede decât e fizic posibil)
	local elapsed = now() - cast.biteAt
	if elapsed < #inputs * Fish.reelStep * 0.5 or elapsed > Fish.biteWindow + #inputs * Fish.reelStep + 3 then
		tell(owner, { state = "result", fish = nil })
		return nil
	end
	local reel = Fishing.newReel()
	local pulls = Fishing.pulls(cast.seed, #inputs)
	for i, input in inputs do
		Fishing.reel(reel, input == true, Fish.reelStep, pulls[i])
		if reel.state ~= "Reeling" then
			break
		end
	end
	if reel.state ~= "Caught" then
		tell(owner, { state = "result", fish = nil, outcome = reel.state })
		return nil
	end
	local fishId = Fishing.roll(function()
		return rng:NextNumber()
	end, FishingService.weather(), FishingService.season())
	local fish = Fish.byId[fishId]
	if fish.egg then
		local rares = {}
		for _, creature in Creatures.list do
			if creature.rarity == "Rare" and creature.seedPrice then
				table.insert(rares, creature.id)
			end
		end
		local seed = rares[rng:NextInteger(1, #rares)]
		owner.profile.seeds[seed] = (owner.profile.seeds[seed] or 0) + 1
		Messenger.notify(owner.player, "fishing.egg", { Messenger.key("creature." .. seed) })
	else
		owner.profile.fish[fishId] = (owner.profile.fish[fishId] or 0) + 1
	end
	local total = 0
	for _, n in owner.profile.fish do
		total += n
	end
	Records.submit("Pescuit", owner, total)
	StateService.markDirty(owner.player)
	tell(owner, { state = "result", fish = fishId })
	return fishId
end

function FishingService.sell(owner: Owner, fishId: string, count: number): number
	local fish = Fish.byId[fishId]
	local have = owner.profile.fish[fishId] or 0
	local n = math.clamp(math.floor(count), 0, have)
	if not fish or n == 0 then
		return 0
	end
	owner.profile.fish[fishId] = have - n
	local lei = fish.sell * n
	EconomyService.addLei(owner, lei)
	Analytics.source(owner.player, owner.profile, lei, "Fish")
	StateService.markDirty(owner.player)
	return lei
end

function FishingService.start()
	Net.get("Fishing").OnServerEvent:Connect(function(player, action, a, b)
		if not limiter:allow(player.UserId, os.clock()) then
			return
		end
		local owner = PlotService.getOwner(player)
		if not owner then
			return
		end
		if action == "cast" then
			FishingService.cast(owner)
		elseif action == "reel" and typeof(a) == "table" then
			local inputs = {}
			for i, v in a do
				if typeof(i) ~= "number" or i > Fish.maxSteps then
					break
				end
				inputs[i] = v == true
			end
			FishingService.reel(owner, inputs)
		elseif action == "sell" and typeof(a) == "string" and typeof(b) == "number" then
			FishingService.sell(owner, a, b)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for owner in casts do
			if owner.player == player then
				casts[owner] = nil
			end
		end
	end)
end

return FishingService
