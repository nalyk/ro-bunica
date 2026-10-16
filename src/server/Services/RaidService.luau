--!strict
-- Furtul: ridicarea creaturii, căratul, depunerea în beciul propriu și scăparea ei.
-- Regula anti-duplicare: creatura rămâne în profilul proprietarului până la depunere.
-- Orice eșec (lovitură, ieșire de pe server, viteză imposibilă) o lasă acolo unde era.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local RaidConfig = require(Shared.Config.Raid)
local Defense = require(Shared.Config.Defense)
local Raid = require(Shared.Domain.Raid)
local Inventory = require(Shared.Domain.Inventory)
local CreatureBuilder = require(Shared.Visual.CreatureBuilder)
local PlotService = require(script.Parent.PlotService)
local CreatureService = require(script.Parent.CreatureService)
local Badges = require(script.Parent.Parent.Badges)
local Analytics = require(script.Parent.Parent.Analytics)
local StateService = require(script.Parent.StateService)
local DayNightService = require(script.Parent.DayNightService)
local Messenger = require(script.Parent.Messenger)
local Actors = require(script.Parent.Parent.Actors)
local FamilyService = require(script.Parent.FamilyService)
local Upgrades = require(Shared.Domain.Upgrades)

type Owner = PlotService.Owner
type Actor = Actors.Actor

type Carry = {
	owner: Owner,
	key: string,
	uid: string,
	model: Model,
	jumpHeight: number,
	lastPosition: Vector3,
	lastTime: number,
}

local CHECK_INTERVAL = 0.1
-- Viteza se măsoară pe o fereastră mai lungă, ca rafalele de replicare să nu dea alarme false
local SPEED_WINDOW = 0.5
local CARRY_HEIGHT = 3.5

local RaidService = {}

local carries: { [Actor]: Carry } = {}
local carriedUids: { [string]: boolean } = {}
local stunnedUntil: { [Actor]: number } = {}
local prompts: { [ProximityPrompt]: boolean } = {}
local forcedIntruders: { [Actor]: Owner } = {} -- intruși și ziua (hoțul din tutorial)

-- Modificatorii de viteză (creatura cărată, Grivei): viteza = baza × produsul lor. Baza se ia la primul
-- modificator și se pune înapoi când nu mai rămâne niciunul, deci efectele nu se calcă pe picioare.
type SpeedState = { base: number, mods: { [string]: number } }
local speeds: { [Actor]: SpeedState } = {}

local function humanoidFor(actor: Actor): Humanoid?
	return Actors.humanoid(actor)
end

local function setSpeedModifier(actor: Actor, name: string, multiplier: number?)
	local humanoid = humanoidFor(actor)
	local state = speeds[actor]
	if not humanoid then
		speeds[actor] = nil
		return
	end
	if multiplier == nil or multiplier == 1 then
		if not state or state.mods[name] == nil then
			return
		end
		state.mods[name] = nil
	else
		if not state then
			state = { base = humanoid.WalkSpeed, mods = {} }
			speeds[actor] = state
		end
		if state.mods[name] == multiplier then
			return
		end
		state.mods[name] = multiplier
	end
	local current = state :: SpeedState
	local speed = current.base
	for _, m in current.mods do
		speed *= m
	end
	humanoid.WalkSpeed = speed
	if next(current.mods) == nil then
		speeds[actor] = nil
	end
end

-- Viteza maximă legitimă cu creatura în brațe (baza × încetinirea de cărat; Grivei doar scade viteza)
local function legitCarrySpeed(actor: Actor, humanoid: Humanoid): number
	local state = speeds[actor]
	if not state then
		return humanoid.WalkSpeed
	end
	return state.base * (state.mods.carry or 1)
end

export type HitSource = {
	kind: string, -- "Slipper" | "RollingPin" | "BunicaSlipper" | "Rage"
	thrower: Actor?, -- cine a aruncat (nil = Bunica)
	owner: Owner, -- ograda apărată
	distance: number, -- de la aruncare la impact
	saved: { id: string, size: string, mutation: string? }?, -- creatura scăpată de hoț (completat de onHit)
}
local hitCallbacks: { (Actor, HitSource) -> () } = {}

-- Diagnostic doar în Studio (playtest), ca să vedem de ce un furt e refuzat
local function debugLog(message: string)
	if RunService:IsStudio() then
		print("[Raid] " .. message)
	end
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local rootOf = Actors.root
local humanoidOf = Actors.humanoid

function RaidService.isCarried(uid: string): boolean
	return carriedUids[uid] == true
end

function RaidService.isCarrying(actor: Actor): boolean
	return carries[actor] ~= nil
end

-- Toți actorii care cară acum o creatură furată, cu ograda de la care au furat-o.
function RaidService.carriers(): { [Actor]: Owner }
	local list = {}
	for actor, carry in carries do
		list[actor] = carry.owner
	end
	return list
end

function RaidService.carryOf(actor: Actor): Owner?
	local carry = carries[actor]
	return if carry then carry.owner else nil
end

function RaidService.isStunned(actor: Actor): boolean
	return (stunnedUntil[actor] or 0) > now()
end

-- Este jucătorul un intrus pentru acest proprietar? (ținta legitimă a papucului)
-- Marchează un actor ca intrus în ograda dată, indiferent de fază (nil = anulează).
function RaidService.forceIntruder(actor: Actor, owner: Owner?)
	if owner then
		forcedIntruders[actor] = owner
	else
		forcedIntruders[actor] = nil
	end
end

-- Apelat după fiecare lovitură (papuc, făcăleț, Bunica, Furie).
function RaidService.onActorHit(callback: (Actor, HitSource) -> ())
	table.insert(hitCallbacks, callback)
end

function RaidService.isIntruder(actor: Actor, owner: Owner): boolean
	if owner.actor == actor then
		return false
	end
	if forcedIntruders[actor] == owner then
		return true
	end
	if FamilyService.sameFamily(actor, owner.actor) then
		return false
	end
	local carry = carries[actor]
	if carry and carry.owner == owner then
		return true
	end
	if DayNightService.phase() ~= "Night" then
		return false
	end
	local root = rootOf(actor)
	return root ~= nil and PlotService.plotAt(root.Position) == owner.plot
end

local function restoreHumanoid(actor: Actor, carry: Carry)
	local humanoid = humanoidOf(actor)
	if humanoid then
		setSpeedModifier(actor, "carry", nil)
		humanoid.JumpHeight = carry.jumpHeight
	end
end

local function endCarry(actor: Actor): Carry?
	local carry = carries[actor]
	if not carry then
		return nil
	end
	carries[actor] = nil
	carriedUids[carry.uid] = nil
	restoreHumanoid(actor, carry)
	carry.model:Destroy()
	return carry
end

-- Creatura scapă și se întoarce pe piedestal (dacă proprietarul mai e în ogradă).
function RaidService.drop(actor: Actor)
	local carry = endCarry(actor)
	if carry and carry.owner.plot.owner == carry.owner and not carry.owner.removing then
		CreatureService.setHidden(carry.owner, carry.key, false)
	end
end

local function complete(actor: Actor, thief: Owner)
	local carry = carries[actor]
	if not carry then
		return
	end
	local owner = carry.owner
	local record = owner.profile.pedestals[carry.key]
	if not record or record.uid ~= carry.uid then
		RaidService.drop(actor)
		return
	end
	-- Verificăm locul la hoț înainte să mutăm ceva
	if not Inventory.freePedestal(thief.profile) and not Inventory.cellarHasRoom(thief.profile) then
		Messenger.notify(actor.player, "notify.Full")
		RaidService.drop(actor)
		return
	end
	endCarry(actor)
	Inventory.takeFromPedestal(owner.profile, carry.key)
	local where, newKey = Inventory.place(thief.profile, table.clone(record))
	CreatureService.setHidden(owner, carry.key, false)
	CreatureService.refreshShowcase(owner)
	if where == "pedestal" and newKey then
		CreatureService.renderKey(thief, newKey)
		CreatureService.refreshShowcase(thief)
	end

	thief.profile.stats.steals += 1
	Analytics.step(thief.player, thief.profile, "FirstSteal")
	Analytics.event(thief.player, "Steal")
	Badges.award(thief.player, "steal")
	Badges.forRarity(thief.player, Creatures.byId[record.id].rarity)
	owner.stolenTonight = (owner.stolenTonight or 0) + 1
	if owner.kind == "Player" then
		owner.shieldUntil = now() + RaidConfig.victimShieldSeconds
	end
	local creatureKey = Messenger.key("creature." .. record.id)
	Messenger.notify(owner.player, "notify.Stolen", { thief.name, creatureKey })
	local rarity = Rarities.byId[Creatures.byId[record.id].rarity]
	if rarity.announceSteal then
		Messenger.announce("announce.Steal", { thief.name, creatureKey, owner.name })
	end
	StateService.markDirty(actor.player)
	StateService.markDirty(owner.player)
end

-- Încearcă să înceapă un furt. Apelat de prompt (jucători) sau direct (boți, teste).
function RaidService.tryStart(actor: Actor, owner: Owner, key: string)
	local thief = PlotService.getOwnerOfActor(actor)
	local root = rootOf(actor)
	local humanoid = humanoidOf(actor)
	local model = CreatureService.modelAt(owner, key)
	local record = owner.profile.pedestals[key]
	if not thief or not root or not humanoid or humanoid.Health <= 0 or not model or not record then
		debugLog(
			string.format(
				"furt refuzat %s: ogradă=%s root=%s humanoid=%s model=%s record=%s",
				actor.name,
				tostring(thief ~= nil),
				tostring(root ~= nil),
				tostring(humanoid ~= nil),
				tostring(model ~= nil),
				tostring(record ~= nil)
			)
		)
		return
	end
	local ok, reason = Raid.canSteal({
		phase = DayNightService.phase(),
		isOwnPlot = thief == owner,
		sameFamily = FamilyService.sameFamily(actor, owner.actor),
		ownerPresent = owner.plot.owner == owner,
		thiefCarrying = carries[actor] ~= nil,
		thiefStunned = RaidService.isStunned(actor),
		ownerShieldUntil = owner.shieldUntil,
		-- Vecinii NPC simpli (fără actor) nu au limită; jucătorii și boții au
		ownerStolenTonight = if owner.actor then owner.stolenTonight or 0 else 0,
		-- În Studio, protecția jucătorilor noi e dezactivată ca să poată fi testate furturile
		ownerPlaySeconds = if RunService:IsStudio() then math.huge else owner.profile.playSeconds,
		ownerIsNpc = owner.kind == "Npc",
		now = now(),
		distance = (root.Position - model:GetPivot().Position).Magnitude,
		creatureOnPedestal = not carriedUids[record.uid],
	})
	if not ok then
		debugLog("furt refuzat " .. actor.name .. ": " .. tostring(reason))
		if
			reason == "NotNight"
			or reason == "Shielded"
			or reason == "NewPlayer"
			or reason == "Family"
			or reason == "NightLimit"
		then
			Messenger.notify(actor.player, "notify." .. reason)
		end
		return
	end

	CreatureService.setHidden(owner, key, true)
	local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt:Destroy()
	end
	CreatureBuilder.attachAbove(model, root, Actors.carryHeight(actor, CARRY_HEIGHT))

	local creature = Creatures.byId[record.id]
	carries[actor] = {
		owner = owner,
		key = key,
		uid = record.uid,
		model = model,
		jumpHeight = humanoid.JumpHeight,
		lastPosition = root.Position,
		lastTime = os.clock(),
	}
	carriedUids[record.uid] = true
	setSpeedModifier(actor, "carry", Raid.carrySpeedMultiplier(creature.rarity))
	humanoid.JumpHeight = RaidConfig.jumpPowerWhileCarrying
	if owner.player then
		Net.get("Alarm"):FireClient(owner.player, owner.plot.index)
	end
end

local function addPrompt(owner: Owner, key: string, model: Model)
	local primary = model.PrimaryPart
	local record = owner.profile.pedestals[key]
	if not primary or not record then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.HoldDuration = Raid.holdSeconds(Creatures.byId[record.id].rarity)
	prompt.MaxActivationDistance = RaidConfig.promptMaxDistance
	prompt.RequiresLineOfSight = false
	prompt.ActionText = "Steal"
	prompt.ObjectText = ""
	prompt.Enabled = DayNightService.phase() == "Night"
	prompt:SetAttribute("Kind", "Steal")
	prompt:SetAttribute("OwnerUserId", owner.userId)
	prompt.Parent = primary
	prompts[prompt] = true
	prompt.Destroying:Connect(function()
		prompts[prompt] = nil
	end)
	prompt.Triggered:Connect(function(player)
		RaidService.tryStart(Actors.forPlayer(player), owner, key)
	end)
end

local function checkCarries()
	for actor, carry in carries do
		local root = rootOf(actor)
		local humanoid = humanoidOf(actor)
		local thief = PlotService.getOwnerOfActor(actor)
		if
			not Actors.isActive(actor)
			or not root
			or not humanoid
			or humanoid.Health <= 0
			or not thief
			or carry.owner.plot.owner ~= carry.owner
		then
			RaidService.drop(actor)
			continue
		end
		local t = os.clock()
		local position = root.Position
		if t - carry.lastTime >= SPEED_WINDOW then
			local plausible = Raid.isMovementPlausible(
				carry.lastPosition,
				position,
				t - carry.lastTime,
				legitCarrySpeed(actor, humanoid),
				Defense.speedCheckTolerance
			)
			carry.lastPosition = position
			carry.lastTime = t
			if not plausible then
				RaidService.drop(actor)
				continue
			end
		end
		if (position - thief.plot.geometry.deposit.Position).Magnitude <= RaidConfig.depositRadius then
			complete(actor, thief)
		end
	end
end

-- Apelat de papuc și de Bunica: scapă creatura, amețește și aruncă actorul.
-- Jucătorul își aplică singur reculul (îi deține fizica); botului i-l aplică serverul.
function RaidService.onHit(victim: Actor, knockback: Vector3, stunSeconds: number, source: HitSource)
	local carry = carries[victim]
	if carry then
		local record = carry.owner.profile.pedestals[carry.key]
		if record then
			source.saved = { id = record.id, size = record.size, mutation = record.mutation }
		end
		RaidService.drop(victim)
	end
	stunnedUntil[victim] = now() + stunSeconds
	if victim.player then
		Net.get("Knockback"):FireClient(victim.player, knockback, stunSeconds)
	else
		-- Botul: ragdoll pe server (îi deținem fizica), apoi se ridică
		local root = Actors.root(victim)
		local humanoid = Actors.humanoid(victim)
		if humanoid then
			humanoid.PlatformStand = true
			task.delay(stunSeconds, function()
				if humanoid.Parent then
					humanoid.PlatformStand = false
				end
			end)
		end
		if root then
			root.AssemblyLinearVelocity = knockback
			root.AssemblyAngularVelocity =
				Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
		end
	end
	for _, callback in hitCallbacks do
		task.spawn(callback, victim, source)
	end
end

-- Grivei: hoții din ograda unui proprietar cu câine merg mai încet cât sunt acolo
local function checkDogs()
	local barking: { [Owner]: boolean } = {}
	for _, actor in Actors.all() do
		local root = rootOf(actor)
		local plot = root and PlotService.plotAt(root.Position)
		local owner = plot and plot.owner
		local slow = 1
		if owner and owner.actor ~= actor and RaidService.isIntruder(actor, owner) then
			slow = Upgrades.dogSlow(owner.profile)
			if slow < 1 then
				barking[owner] = true
			end
		end
		setSpeedModifier(actor, "dog", if slow < 1 then slow else nil)
	end
	-- Grivei latră (clientul îl animă) cât are hoți în ogradă
	for _, owner in PlotService.owners() do
		local dog = owner.plot.geometry.model:FindFirstChild("Grivei")
		if dog then
			dog:SetAttribute("Barking", barking[owner] == true)
		end
	end
end

-- Verificarea furturilor în curs (rulată pe Heartbeat; expusă pentru teste).
RaidService.checkCarries = checkCarries
RaidService.checkDogs = checkDogs

function RaidService.start()
	CreatureService.onModelCreated(addPrompt)
	DayNightService.onPhaseChanged(function(phase)
		for prompt in prompts do
			prompt.Enabled = phase == "Night"
		end
		-- Limita de furturi pe noapte se resetează
		for _, owner in PlotService.owners() do
			owner.stolenTonight = 0
		end
	end)
	PlotService.onOwnerRemoving(function(owner)
		for actor, carry in carries do
			-- Proprietarul pleacă: creatura cărată rămâne a lui. Hoțul pleacă: scapă ce căra.
			if carry.owner == owner or actor == owner.actor then
				RaidService.drop(actor)
			end
		end
	end)
	Actors.onRemoving(function(actor)
		RaidService.drop(actor)
		stunnedUntil[actor] = nil
		forcedIntruders[actor] = nil
		speeds[actor] = nil
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= CHECK_INTERVAL then
			elapsed = 0
			checkCarries()
			checkDogs()
		end
	end)
end

return RaidService
