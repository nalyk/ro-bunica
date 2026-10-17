--!strict
-- Caietul Bunicii: colecția (descoperiri cu lei, praguri cu venit permanent, Rețeta Secretă la 50 de intrări),
-- treburile zilei (3 pe zi UTC, recompense pe măsura venitului, bonus o sămânță) și renașterea
-- („Gospodăria nouă”, +50% venit pe nivel). Progresul vine din evenimentele jocului (Server/Progress).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Notebook = require(Shared.Config.Notebook)
local Collection = require(Shared.Domain.Collection)
local Quests = require(Shared.Domain.Quests)
local Rebirth = require(Shared.Domain.Rebirth)
local Daily = require(Shared.Domain.Daily)
local Economy = require(Shared.Domain.Economy)
local RateLimiter = require(Shared.Domain.RateLimiter)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)
local CreatureService = require(script.Parent.CreatureService)
local GardenService = require(script.Parent.GardenService)
local EconomyService = require(script.Parent.EconomyService)
local RaidService = require(script.Parent.RaidService)
local DayNightService = require(script.Parent.DayNightService)
local TutorialService = require(script.Parent.TutorialService)
local Messenger = require(script.Parent.Messenger)
local Progress = require(script.Parent.Parent.Progress)
local Analytics = require(script.Parent.Parent.Analytics)

type Owner = PlotService.Owner

local DAY_CHECK_SECONDS = 30

local NotebookService = {}

local limiter = RateLimiter.new(6, 2)

local function today(): number
	return Daily.dayOf(os.time())
end

-- Tăblița ogrăzii arată renașterile ca steluțe
local function renderSign(owner: Owner)
	local stars = owner.profile.rebirths
	owner.plot.geometry.sign.Text = if stars > 0
		then owner.name .. " " .. string.rep("★", stars)
		else owner.name
	owner.plot.geometry.model:SetAttribute("Rebirths", stars)
end

-- Descoperă o creatură în caiet: lei, praguri, Rețeta Secretă.
local function discover(owner: Owner, record: any)
	local found = Collection.discover(owner.profile, record)
	if not found then
		return
	end
	local player = owner.player
	EconomyService.addLei(owner, found.lei)
	Analytics.source(player, owner.profile, found.lei, "Collection", found.key)
	local creatureKey = Messenger.key("creature." .. record.id)
	if record.mutation then
		Messenger.notify(
			player,
			"notify.DiscoveredMutation",
			{ creatureKey, Messenger.key("mutation." .. record.mutation), Economy.formatShort(found.lei) }
		)
	else
		Messenger.notify(player, "notify.Discovered", { creatureKey, Economy.formatShort(found.lei) })
	end
	if found.milestone then
		Messenger.notify(player, "notify.CollectionMilestone", { found.milestone })
	end
	if found.secret then
		-- Rețeta Secretă vine ca sămânță: o plantezi și eclozează (are mereu loc, chiar cu beciul plin)
		local secret = Notebook.collection.secretId
		owner.profile.seeds[secret] = (owner.profile.seeds[secret] or 0) + 1
		Messenger.notify(player, "notify.SecretRecipe")
		Messenger.announce("announce.SecretRecipe", { owner.name })
	end
	StateService.markDirty(player)
end

local function onProgress(owner: Owner, kind: string, amount: number, record: any?)
	if owner.plot.owner ~= owner or owner.removing then
		return
	end
	if kind == "obtained" then
		if record then
			discover(owner, record)
		end
		return
	end
	Quests.ensure(owner.profile, today(), owner.userId)
	local done = Quests.record(owner.profile, kind, amount)
	for _, index in done do
		Messenger.notify(
			owner.player,
			"notify.QuestDone",
			{ Messenger.key("quest." .. owner.profile.quests.list[index].kind) }
		)
	end
	StateService.markDirty(owner.player)
end

-- Venitul pe secundă al jucătorului, cu toți multiplicatorii (pentru recompensele treburilor)
local function incomeOf(owner: Owner): number
	local multiplier = if owner.player then EconomyService.multiplier(owner.player) else 1
	return Economy.totalIncome(owner.profile.pedestals, multiplier)
end

function NotebookService.claimQuest(owner: Owner, index: number): number?
	Quests.ensure(owner.profile, today(), owner.userId)
	local lei = Quests.claim(owner.profile, index, incomeOf(owner))
	if lei then
		EconomyService.addLei(owner, lei)
		Analytics.source(owner.player, owner.profile, lei, "Quest", owner.profile.quests.list[index].kind)
		Messenger.notify(owner.player, "notify.QuestReward", { Economy.formatShort(lei) })
		StateService.markDirty(owner.player)
	end
	return lei
end

function NotebookService.claimBonus(owner: Owner): string?
	local seed = Quests.claimBonus(owner.profile)
	if seed then
		Messenger.notify(owner.player, "notify.QuestBonus", { Messenger.key("creature." .. seed) })
		StateService.markDirty(owner.player)
	end
	return seed
end

-- Renașterea: doar ziua (noaptea creaturile pot fi în brațele hoților) și nu în scena din primul minut.
function NotebookService.rebirth(owner: Owner): boolean
	if DayNightService.phase() ~= "Day" or TutorialService.isActive(owner) then
		Messenger.notify(owner.player, "notify.RebirthDayOnly")
		return false
	end
	for _, record in owner.profile.pedestals do
		if RaidService.isCarried(record.uid) then
			return false
		end
	end
	local ok, reason = Rebirth.canRebirth(owner.profile)
	if not ok then
		Messenger.notify(owner.player, "notify." .. tostring(reason))
		return false
	end
	local paid = owner.profile.lei
	Rebirth.apply(owner.profile)
	Analytics.sink(owner.player, owner.profile, paid, "Rebirth", "level" .. owner.profile.rebirths)
	CreatureService.render(owner)
	CreatureService.refreshShowcase(owner)
	GardenService.refreshBeds(owner)
	EconomyService.addLei(owner, 0) -- clasamentul și starea
	renderSign(owner)
	Messenger.notify(owner.player, "notify.Reborn", { owner.profile.rebirths })
	Messenger.announce("announce.Rebirth", { owner.name :: any, owner.profile.rebirths })
	StateService.markDirty(owner.player)
	return true
end

local function onRequest(player: Player, action: unknown, arg: unknown)
	if not limiter:allow(player.UserId, os.clock()) then
		return
	end
	local owner = PlotService.getOwner(player)
	if not owner then
		return
	end
	if action == "claimQuest" and typeof(arg) == "number" and arg == math.floor(arg) then
		NotebookService.claimQuest(owner, arg)
	elseif action == "claimBonus" then
		NotebookService.claimBonus(owner)
	elseif action == "rebirth" then
		NotebookService.rebirth(owner)
	end
end

function NotebookService.start()
	Progress.on(onProgress)
	Net.get("Notebook").OnServerEvent:Connect(onRequest)

	-- Apărarea: cine scapă o creatură din brațele unui hoț
	RaidService.onActorHit(function(_victim, source)
		if source.saved and source.thrower then
			Progress.emit(PlotService.getOwnerOfActor(source.thrower), "defend")
		end
	end)

	PlotService.onOwnerAdded(function(owner)
		if owner.kind ~= "Player" then
			return
		end
		-- Ce avea deja jucătorul intră în caiet fără recompensă (descoperit înainte de caiet)
		for _, record in owner.profile.pedestals do
			Collection.discover(owner.profile, record)
		end
		for _, record in owner.profile.cellar do
			Collection.discover(owner.profile, record)
		end
		Quests.ensure(owner.profile, today(), owner.userId)
		renderSign(owner)
		StateService.markDirty(owner.player)
	end)

	StateService.addProvider(function(player, state)
		local owner = PlotService.getOwner(player)
		if not owner then
			return
		end
		local profile = owner.profile
		state.notebook = {
			collection = profile.collection,
			count = Collection.count(profile),
			total = Collection.TOTAL,
			quests = profile.quests,
			rebirths = profile.rebirths,
			rebirthCost = Rebirth.cost(profile.rebirths),
			incomeMultiplier = EconomyService.multiplier(player),
		}
	end)

	-- O zi nouă (UTC) aduce treburi noi și pentru cine e deja pe server
	while true do
		task.wait(DAY_CHECK_SECONDS)
		local day = today()
		for _, player in Players:GetPlayers() do
			local owner = PlotService.getOwner(player)
			if owner and Quests.ensure(owner.profile, day, owner.userId) then
				StateService.markDirty(player)
			end
		end
	end
end

return NotebookService
