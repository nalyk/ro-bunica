--!strict
-- Vecinii fură și ei: noaptea, un vecin NPC trimite un hoț spre ograda unui jucător activ (mai mulți când
-- serverul e gol). Hoțul e un bot cu regulile furtului de la jucători (RaidService): papucul îl doboară,
-- Bunica îl vede, alarma sună, apărarea e răsplătită. Ce fură ajunge pe piedestalul vecinului, de unde
-- jucătorul îl poate fura înapoi. Cine e AFK, nou sau protejat nu e țintă; Legendarele și peste nu sunt luate.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local NpcThievesConfig = require(Shared.Config.NpcThieves)
local RaidConfig = require(Shared.Config.Raid)
local EconomyConfig = require(Shared.Config.Economy)
local World = require(Shared.Config.World)
local NpcThieves = require(Shared.Domain.NpcThieves)
local Raid = require(Shared.Domain.Raid)
local Creatures = require(Shared.Config.Creatures)
local Inventory = require(Shared.Domain.Inventory)
local PlotService = require(script.Parent.PlotService)
local CreatureService = require(script.Parent.CreatureService)
local RaidService = require(script.Parent.RaidService)
local DayNightService = require(script.Parent.DayNightService)
local TutorialService = require(script.Parent.TutorialService)
local Messenger = require(script.Parent.Messenger)
local Analytics = require(script.Parent.Parent.Analytics)
local Actors = require(script.Parent.Parent.Actors)
local Walker = require(script.Parent.Parent.Ai.Walker)

type Owner = PlotService.Owner
type Actor = Actors.Actor

-- Cum se deplasează botul spre un punct; testele e2e (fără fizică) dau unul care mută botul în pași.
export type Mover = (actor: Actor, point: Vector3, shouldStop: () -> boolean) -> boolean
export type Outcome = "Stolen" | "Hit" | "GaveUp" | "NoTarget"

local ACTIVITY_SAMPLE_SECONDS = 2
local MOVED_STUDS = 2

local NpcThiefService = {}

local enabled = true
local lastActive: { [Player]: number } = {}
local lastPosition: { [Player]: Vector3 } = {}
local hitBots: { [Actor]: boolean } = {}
local nightId = 0

-- Merge cu pathfinding până ajunge sau până cere `shouldStop` (termenul e în shouldStop): după o blocare
-- (gard, alt personaj) replanifică din nou, nu renunță după câteva încercări.
local function defaultMover(actor: Actor, point: Vector3, shouldStop: () -> boolean): boolean
	while not shouldStop() do
		local humanoid = Actors.humanoid(actor)
		local root = Actors.root(actor)
		if not humanoid or not root then
			return false
		end
		if Walker.pathTo(humanoid, root, point, shouldStop) then
			return true
		end
		task.wait(0.2)
	end
	return false
end

-- Pornește sau oprește hoții vecini (testele și playtest-ul îi opresc ca să nu încurce alte scene).
function NpcThiefService.setEnabled(value: boolean)
	enabled = value
end

-- Pentru teste: marchează jucătorul ca activ acum.
function NpcThiefService.markActive(player: Player)
	lastActive[player] = os.clock()
end

-- Poate fi jucătorul ținta unui hoț vecin acum?
function NpcThiefService.eligible(owner: Owner): boolean
	local player = owner.player
	if owner.kind ~= "Player" or not player or owner.removing or owner.plot.owner ~= owner then
		return false
	end
	if not NpcThieves.isActive(lastActive[player], os.clock()) then
		return false
	end
	-- În Studio, protecția jucătorilor noi e dezactivată (ca în RaidService), ca hoții să poată fi testați
	if not RunService:IsStudio() and owner.profile.playSeconds < RaidConfig.newPlayerProtectionSeconds then
		return false
	end
	if Workspace:GetServerTimeNow() < owner.shieldUntil then
		return false
	end
	if
		(owner.stolenTonight or 0) >= RaidConfig.maxStealsPerVictimPerNight or TutorialService.isActive(owner)
	then
		return false
	end
	return NpcThieves.pickTarget(owner.profile.pedestals, RaidService.isCarried) ~= nil
end

-- Vecinul NPC liber (fără bot legat de el) cel mai apropiat de ograda țintă: hoțul vine de alături.
function NpcThiefService.freeNeighbour(target: Owner?): Owner?
	local best: Owner? = nil
	local bestDistance = math.huge
	for _, owner in PlotService.owners() do
		if owner.kind == "Npc" and owner.actor == nil and not owner.removing then
			local distance = if target
				then (owner.plot.geometry.cframe.Position - target.plot.geometry.cframe.Position).Magnitude
				else math.random()
			if distance < bestDistance then
				best, bestDistance = owner, distance
			end
		end
	end
	return best
end

local function debugLog(message: string)
	if RunService:IsStudio() then
		print("[NpcThief] " .. message)
	end
end

-- Creatura furată trebuie să ajungă pe un piedestal al vecinului (de acolo se fură înapoi), nu în beciul lui:
-- vecinul deblochează un piedestal sau, dacă le are pe toate, își vinde un Comun.
local function ensureFreePedestal(npc: Owner)
	local profile = npc.profile
	if Inventory.freePedestal(profile) then
		return
	end
	if profile.pedestalCount < EconomyConfig.maxPedestals then
		profile.pedestalCount += 1
	else
		for key, record in profile.pedestals do
			local creature = Creatures.byId[record.id]
			if creature and creature.rarity == "Common" then
				Inventory.takeFromPedestal(profile, key)
				break
			end
		end
	end
	CreatureService.render(npc)
end

local function release(npc: Owner, bot: Actor)
	-- Întâi dezlegăm botul de ograda vecinului: altfel PlotService ar înlocui vecinul (și creatura furată)
	if npc.actor == bot then
		npc.actor = nil
	end
	hitBots[bot] = nil
	Actors.removeBot(bot)
end

-- O încercare de furt: vecinul `npc` trimite un hoț după cea mai valoroasă creatură (până la Epic) a lui `target`.
local function attempt(target: Owner, npc: Owner, mover: Mover?): Outcome
	local move: Mover = mover or defaultMover
	local key = NpcThieves.pickTarget(target.profile.pedestals, RaidService.isCarried)
	local model = key and CreatureService.modelAt(target, key)
	if not key or not model then
		return "NoTarget"
	end
	local record = target.profile.pedestals[key]
	local uid = record.uid
	ensureFreePedestal(npc)
	local npcGeometry = npc.plot.geometry
	local halfDepth = World.plotSize.Z / 2
	local home = (npcGeometry.cframe * CFrame.new(0, 3, -halfDepth + 6)).Position -- în ograda vecinului, la poartă
	local bot = Actors.createBot(npc.name, CFrame.new(home), NpcThievesConfig.look)
	npc.actor = bot
	local humanoid = Actors.humanoid(bot)
	if humanoid then
		humanoid.WalkSpeed = NpcThievesConfig.walkSpeed
	end
	Messenger.notify(target.player, "notify.NpcThiefComing", { npc.name })

	local function gone(): boolean
		return DayNightService.phase() ~= "Night"
			or not bot.alive
			or target.removing
			or target.plot.owner ~= target
			or npc.removing
			or npc.plot.owner ~= npc
	end

	-- 1. Până la creatură (în fața ei, dinspre drum)
	local approach = model:GetPivot().Position + target.plot.geometry.cframe.LookVector * 4
	local approachDeadline = os.clock() + NpcThievesConfig.approachSeconds
	move(bot, approach, function()
		return gone() or hitBots[bot] == true or os.clock() > approachDeadline
	end)
	if
		not gone()
		and not hitBots[bot]
		and target.profile.pedestals[key]
		and target.profile.pedestals[key].uid == uid
	then
		RaidService.tryStart(bot, target, key)
	end

	local reachedCreature = RaidService.isCarrying(bot)
	-- 2. Acasă, la beciul vecinului (RaidService încheie furtul la depunere)
	if RaidService.isCarrying(bot) then
		local root = Actors.root(bot)
		local straight = if root then (npcGeometry.deposit.Position - root.Position).Magnitude else 200
		local carrySpeed = NpcThievesConfig.walkSpeed
			* Raid.carrySpeedMultiplier(Creatures.byId[record.id].rarity)
		local carryDeadline = os.clock()
			+ straight / carrySpeed * NpcThievesConfig.carrySlack
			+ NpcThievesConfig.carryExtraSeconds
		local nextTrace = 0
		move(bot, npcGeometry.deposit.Position, function()
			local rootNow = Actors.root(bot)
			if RunService:IsStudio() and rootNow and os.clock() >= nextTrace then
				nextTrace = os.clock() + 4
				debugLog(
					string.format(
						"cară: la %.0f studs de beci, mai are %.0f s",
						(rootNow.Position - npcGeometry.deposit.Position).Magnitude,
						carryDeadline - os.clock()
					)
				)
			end
			return not RaidService.isCarrying(bot) or gone() or os.clock() > carryDeadline
		end)
		local settle = os.clock() + 1
		while RaidService.isCarrying(bot) and os.clock() < settle do
			task.wait(0.1)
		end
		RaidService.drop(bot) -- dacă n-a ajuns: creatura se întoarce acasă
	end

	local stolen = Inventory.findPedestal(npc.profile, uid) ~= nil
		or Inventory.findCellar(npc.profile, uid) ~= nil
	local outcome: Outcome = if stolen then "Stolen" elseif hitBots[bot] then "Hit" else "GaveUp"
	local finalRoot = Actors.root(bot)
	debugLog(
		string.format(
			"%s → %s: %s (a ajuns la creatură: %s, la %.0f studs de beciul vecinului)",
			npc.name,
			target.name,
			outcome,
			tostring(reachedCreature),
			if finalRoot then (finalRoot.Position - npcGeometry.deposit.Position).Magnitude else -1
		)
	)
	if stolen then
		Messenger.notify(target.player, "notify.StealBack", { npc.name })
	end
	Analytics.event(target.player, "NpcThief" .. outcome)

	-- 3. Pleacă înapoi în ograda lui și dispare
	task.spawn(function()
		if hitBots[bot] then
			task.wait(1.5) -- amețit
		end
		local leaveDeadline = os.clock() + 15
		move(bot, home, function()
			return not bot.alive or os.clock() > leaveDeadline
		end)
		release(npc, bot)
	end)
	return outcome
end

-- Protejată: orice eroare eliberează botul, ca vecinul să nu rămână legat de un bot pentru totdeauna.
function NpcThiefService.attempt(target: Owner, npc: Owner, mover: Mover?): Outcome
	local ok, result = pcall(attempt, target, npc, mover)
	if ok then
		return result :: Outcome
	end
	warn("[NpcThiefService] încercarea a eșuat:", result)
	local bot = npc.actor
	if bot then
		RaidService.drop(bot)
		release(npc, bot)
	end
	return "GaveUp"
end

local function realPlayers(): number
	return #Players:GetPlayers()
end

local function runNight(id: number)
	local attempts = NpcThieves.attempts(realPlayers())
	local targeted: { [Owner]: number } = {}
	for index = 1, attempts do
		task.wait(
			NpcThieves.delay(
				if index == 1 then NpcThievesConfig.firstDelay else NpcThievesConfig.betweenDelay,
				math.random
			)
		)
		if nightId ~= id or not enabled or DayNightService.phase() ~= "Night" then
			return
		end
		-- ținta: un jucător eligibil, cât mai puțin vizitat în noaptea asta
		local best: Owner? = nil
		local bestCount = math.huge
		for _, owner in PlotService.owners() do
			if NpcThiefService.eligible(owner) then
				local count = (targeted[owner] or 0) + math.random() * 0.5
				if count < bestCount then
					best, bestCount = owner, count
				end
			end
		end
		local npc = if best then NpcThiefService.freeNeighbour(best) else nil
		if best and npc then
			targeted[best] = (targeted[best] or 0) + 1
			task.spawn(NpcThiefService.attempt, best, npc)
		end
	end
end

local function sampleActivity()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local previous = lastPosition[player]
			if previous and (root.Position - previous).Magnitude >= MOVED_STUDS then
				lastActive[player] = now
			end
			lastPosition[player] = root.Position
		end
	end
end

function NpcThiefService.start()
	RaidService.onActorHit(function(victim)
		if Actors.isBot(victim) then
			hitBots[victim] = true
		end
	end)
	DayNightService.onPhaseChanged(function(phase)
		nightId += 1
		if phase == "Night" and enabled then
			task.spawn(runNight, nightId)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastActive[player] = nil
		lastPosition[player] = nil
	end)
	while true do
		task.wait(ACTIVITY_SAMPLE_SECONDS)
		sampleActivity()
	end
end

return NpcThiefService
