--!strict
-- Papucul și făcălețul: muniție, Nervi, proiectile simulate pe server și lovituri.
-- Clienții primesc proiectilele doar pentru randare; lovitura o decide serverul.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Defense = require(Shared.Config.Defense)
local Upgrades = require(Shared.Domain.Upgrades)
local World = require(Shared.Config.World)
local Slipper = require(Shared.Domain.Slipper)
local AimAssist = require(Shared.Domain.AimAssist)
local Juice = require(Shared.Config.Juice)
local RateLimiter = require(Shared.Domain.RateLimiter)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)
local DayNightService = require(script.Parent.DayNightService)
local RaidService = require(script.Parent.RaidService)
local Zones = require(script.Parent.Parent.World.Zones)
local Busy = require(script.Parent.Parent.Busy)
local Messenger = require(script.Parent.Messenger)
local Actors = require(script.Parent.Parent.Actors)
local FamilyService = require(script.Parent.FamilyService)

type Actor = Actors.Actor

type Owner = PlotService.Owner

export type ProjectileParams = {
	speed: number,
	gravity: number,
	hitRadius: number,
	maxRange: number,
	maxLifetime: number,
	stunSeconds: number,
	knockbackSpeed: number,
}

type Projectile = {
	id: number,
	kind: string,
	owner: Owner,
	thrower: Actor?,
	origin: Vector3,
	velocity: Vector3,
	params: ProjectileParams,
	age: number,
	last: Vector3,
	pierces: boolean, -- făcălețul lovește tot ce prinde pe traiectorie
	alreadyHit: { [Actor]: boolean },
	hits: number,
	defends: { Owner }, -- ogrăzile apărate: a aruncătorului și ale familiei lui
}

local TARGET_RADIUS = 2.5

local SlipperService = {}

local throwLimiter = RateLimiter.new(6, 4)
local ammoByActor: { [Actor]: Slipper.Ammo } = {}
local nerviByActor: { [Actor]: number } = {}
local projectiles: { Projectile } = {}
local nextId = 0

-- Ajutor la ochit pe actor: funcția întoarce țintele spre care se pot redirecționa aruncările
type AimAssistEntry = { targets: () -> { Vector3 }, radius: number }
local aimAssist: { [Actor]: AimAssistEntry } = {}

-- Cea mai lungă lovitură a nopții, reluată la răsărit
export type BestThrow = {
	name: string,
	distance: number,
	kind: string,
	origin: Vector3,
	velocity: Vector3,
	gravity: number,
	duration: number,
	plotIndex: number,
}
local bestThrow: BestThrow? = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function maxAmmo(owner: Owner): number
	return Defense.slipper.maxAmmo + (owner.profile.upgrades.ammo or 0)
end

-- Secunde între doi papuci (îmbunătățirea „regen”)
local function regenSeconds(owner: Owner): number
	return Upgrades.regenSeconds(owner.profile)
end

local function isFiniteVector(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 1e6
end

function SlipperService.nervi(actor: Actor): number
	return nerviByActor[actor] or 0
end

-- Consumă Nervi; întoarce false dacă nu sunt destui.
function SlipperService.spendNervi(actor: Actor, amount: number): boolean
	local current = nerviByActor[actor] or 0
	if current < amount then
		return false
	end
	nerviByActor[actor] = current - amount
	StateService.markDirty(actor.player)
	return true
end

local function addNervi(actor: Actor, amount: number)
	nerviByActor[actor] = math.min((nerviByActor[actor] or 0) + amount, Defense.nervi.max)
	StateService.markDirty(actor.player)
end

-- Lansează un proiectil care poate lovi intrușii ogrăzii `owner`.
function SlipperService.launch(
	owner: Owner,
	thrower: Actor?,
	kind: string,
	origin: Vector3,
	target: Vector3,
	params: ProjectileParams
)
	nextId += 1
	local velocity = Slipper.launchVelocity(origin, target, params.speed, params.gravity, params.maxRange)
	local projectile: Projectile = {
		id = nextId,
		kind = kind,
		owner = owner,
		thrower = thrower,
		origin = origin,
		velocity = velocity,
		params = params,
		age = 0,
		last = origin,
		pierces = kind == "RollingPin",
		alreadyHit = {},
		hits = 0,
		-- în mini-joc, papucul e al jocului: nu apără ogrăzi (lovește doar țintele înregistrate)
		defends = if thrower and Busy.is(thrower)
			then {}
			elseif thrower then FamilyService.familyOwners(owner)
			else { owner },
	}
	table.insert(projectiles, projectile)
	Net.get("Projectile"):FireAllClients({
		id = projectile.id,
		kind = kind,
		origin = origin,
		velocity = velocity,
		gravity = params.gravity,
		lifetime = params.maxLifetime,
		startTime = now(),
		throwerUserId = if thrower then thrower.id else 0,
		plotIndex = owner.plot.index,
	})
end

local function knockbackFor(owner: Owner, victimPosition: Vector3, speed: number): Vector3
	-- Hoțul zboară spre poarta ogrăzii
	local gate = owner.plot.geometry.cframe * CFrame.new(0, 0, -World.plotSize.Z / 2)
	local flat = Vector3.new(gate.Position.X - victimPosition.X, 0, gate.Position.Z - victimPosition.Z)
	local direction = if flat.Magnitude > 0.1 then flat.Unit else owner.plot.geometry.cframe.LookVector
	return direction * speed + Vector3.new(0, speed * 0.6, 0)
end

SlipperService.knockbackFor = knockbackFor

local missCallbacks: { (Owner, Actor) -> () } = {}

-- Apelat când un papuc aruncat de un actor nu nimerește pe nimeni.
function SlipperService.onMiss(callback: (Owner, Actor) -> ())
	table.insert(missCallbacks, callback)
end

local function applyHit(projectile: Projectile, victim: Actor, root: BasePart, defended: Owner)
	projectile.alreadyHit[victim] = true
	projectile.hits += 1
	local params = projectile.params
	local distance = (root.Position - projectile.origin).Magnitude
	local thrower = projectile.thrower
	if thrower then
		-- înainte de RaidService.onHit: ascultătorii lui (clasamentul din EconomyService) citesc statistica
		projectile.owner.profile.stats.defends += 1 -- statistica e a celui care aruncă
	end
	RaidService.onHit(
		victim,
		knockbackFor(defended, root.Position, params.knockbackSpeed),
		params.stunSeconds,
		{
			kind = projectile.kind,
			thrower = projectile.thrower,
			owner = defended,
			distance = distance,
		}
	)
	if thrower then
		addNervi(thrower, Defense.nervi.perHit)
		Messenger.notify(thrower.player, "notify.Defended", { victim.name })
		if not bestThrow or distance > bestThrow.distance then
			bestThrow = {
				name = thrower.name,
				distance = distance,
				kind = projectile.kind,
				origin = projectile.origin,
				velocity = projectile.velocity,
				gravity = params.gravity,
				duration = projectile.age,
				plotIndex = projectile.owner.plot.index,
			}
		end
	end
	Net.get("Hit"):FireAllClients({
		id = projectile.id,
		kind = projectile.kind,
		position = root.Position,
		victimUserId = victim.id,
		throwerUserId = if thrower then thrower.id else 0,
		distance = distance,
		plotIndex = defended.plot.index,
	})
end

-- Pornește sau oprește ajutorul la ochit pentru un actor (tutorial, jucători noi).
function SlipperService.setAimAssist(actor: Actor, targets: (() -> { Vector3 })?, radius: number?)
	if targets then
		aimAssist[actor] = { targets = targets, radius = radius or 20 }
	else
		aimAssist[actor] = nil
	end
end

function SlipperService.bestThrow(): BestThrow?
	return bestThrow
end

-- Ținte în afara ogrăzilor (lupii, Muma Pădurii, ținte de mini-joc): oricine aruncă le poate lovi.
type Target = { model: Model, radius: number, onHit: (thrower: Actor?, kind: string) -> () }
local targets: { [Model]: Target } = {}

function SlipperService.registerTarget(
	model: Model,
	onHit: (thrower: Actor?, kind: string) -> (),
	radius: number?
)
	targets[model] = { model = model, radius = radius or 2.5, onHit = onHit }
end

function SlipperService.unregisterTarget(model: Model)
	targets[model] = nil
end

local function hitTargets(projectile: Projectile, from: Vector3, to: Vector3): boolean
	for model, target in targets do
		if not model.Parent then
			targets[model] = nil
			continue
		end
		local at = model:GetPivot().Position
		if Slipper.hits(from, to, at, projectile.params.hitRadius, target.radius) then
			projectile.hits += 1
			task.spawn(target.onHit, projectile.thrower, projectile.kind)
			return true
		end
	end
	return false
end

local function step(dt: number)
	for index = #projectiles, 1, -1 do
		local projectile = projectiles[index]
		projectile.age += dt
		local position = Slipper.positionAt(
			projectile.origin,
			projectile.velocity,
			projectile.params.gravity,
			projectile.age
		)
		local finished = projectile.age >= projectile.params.maxLifetime or position.Y < -5
		for _, actor in Actors.all() do
			if projectile.alreadyHit[actor] then
				continue
			end
			-- Prima ogradă apărată în care actorul e intrus
			local defended: Owner? = nil
			for _, candidate in projectile.defends do
				if RaidService.isIntruder(actor, candidate) then
					defended = candidate
					break
				end
			end
			if not defended then
				continue
			end
			local root = Actors.root(actor)
			if root and not RaidService.isCarrying(actor) and Zones.noFight(root.Position) then
				continue -- la adăpost în centru (doar cine nu cară o creatură furată)
			end
			if
				root
				and Slipper.hits(
					projectile.last,
					position,
					root.Position,
					projectile.params.hitRadius,
					TARGET_RADIUS
				)
			then
				applyHit(projectile, actor, root, defended)
				if not projectile.pierces then
					finished = true
					break
				end
			end
		end
		if not finished and next(targets) ~= nil and hitTargets(projectile, projectile.last, position) then
			finished = true
		end
		projectile.last = position
		if finished then
			table.remove(projectiles, index)
			local thrower = projectile.thrower
			if projectile.hits == 0 and thrower then
				for _, callback in missCallbacks do
					task.spawn(callback, projectile.owner, thrower)
				end
			end
		end
	end
end

-- Aruncarea unui actor care își apără ograda. Întoarce true dacă a pornit un proiectil.
function SlipperService.throwAs(actor: Actor, target: Vector3, kind: "Slipper" | "RollingPin"): boolean
	if RaidService.isStunned(actor) then
		return false
	end
	local owner = PlotService.getOwnerOfActor(actor)
	local root = Actors.root(actor)
	if not owner or not root then
		return false
	end
	if Zones.noFight(root.Position) then
		return false -- în centrul satului nu se aruncă
	end
	local params: ProjectileParams
	if kind == "RollingPin" then
		if not SlipperService.spendNervi(actor, Defense.rollingPin.cost) then
			return false
		end
		params = Defense.rollingPin
	else
		local ammo = ammoByActor[actor]
		if not ammo then
			ammo = Slipper.newAmmo(maxAmmo(owner), now())
			ammoByActor[actor] = ammo
		end
		if not Slipper.consume(ammo, now(), maxAmmo(owner), regenSeconds(owner)) then
			return false
		end
		params = Defense.slipper
		StateService.markDirty(actor.player)
	end
	local assist = aimAssist[actor]
	if assist then
		local before = target
		target = AimAssist.retarget(target, assist.targets(), assist.radius)
		if RunService:IsStudio() then
			print(
				string.format(
					"[Slipper] ajutor la ochit %s: %.1f studs corecție, țintă la %.1f studs",
					actor.name,
					(target - before).Magnitude,
					(target - root.Position).Magnitude
				)
			)
		end
	end
	local origin = root.Position + Vector3.new(0, 2, 0)
	SlipperService.launch(owner, actor, kind, origin, target, params)
	return true
end

local function onThrow(player: Player, target: unknown, kind: unknown)
	if typeof(target) ~= "Vector3" or not isFiniteVector(target :: Vector3) then
		return
	end
	if kind ~= "Slipper" and kind ~= "RollingPin" then
		return
	end
	if not throwLimiter:allow(player.UserId, os.clock()) then
		return
	end
	local actor = Actors.forPlayer(player)
	local root = Actors.root(actor)
	if root and Zones.noFight(root.Position) then
		Messenger.notify(player, "notify.NoFight")
		return
	end
	SlipperService.throwAs(actor, target :: Vector3, kind :: any)
end

-- Avansează proiectilele (rulat pe Heartbeat; expus pentru teste).
SlipperService.step = step

function SlipperService.start()
	Net.get("Throw").OnServerEvent:Connect(onThrow)
	PlotService.onOwnerAdded(function(owner)
		local actor = owner.actor
		if actor then
			ammoByActor[actor] = Slipper.newAmmo(maxAmmo(owner), now())
			nerviByActor[actor] = 0
		end
	end)
	Actors.onRemoving(function(actor)
		ammoByActor[actor] = nil
		nerviByActor[actor] = nil
		aimAssist[actor] = nil
		throwLimiter:forget(actor.id)
	end)
	DayNightService.onPhaseChanged(function(phase)
		if phase == "Night" then
			bestThrow = nil
		end
		-- Lovitura nopții, reluată pentru tot serverul la răsărit
		local best = bestThrow
		if phase == "Day" and best and best.distance >= Juice.replayMinDistance then
			Net.get("Replay"):FireAllClients(best)
			Messenger.announce("announce.BestThrow", { best.name, tostring(math.floor(best.distance)) })
			bestThrow = nil
		end
		if phase == "Day" then
			for actor in nerviByActor do
				nerviByActor[actor] = 0
				StateService.markDirty(actor.player)
			end
		end
	end)
	StateService.addProvider(function(player, state)
		local actor = Actors.forPlayer(player)
		local owner = PlotService.getOwner(player)
		local ammo = ammoByActor[actor]
		if owner and ammo then
			Slipper.updateAmmo(ammo, now(), maxAmmo(owner), regenSeconds(owner))
			state.ammo = ammo.ammo
			state.ammoRegenStart = ammo.regenStart
			state.maxAmmo = maxAmmo(owner)
			state.ammoRegenSeconds = regenSeconds(owner)
		end
		state.nervi = nerviByActor[actor] or 0
	end)
	RunService.Heartbeat:Connect(step)
end

return SlipperService
