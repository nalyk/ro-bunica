--!strict
-- Papucul și făcălețul: muniție, Nervi, proiectile simulate pe server și lovituri.
-- Clienții primesc proiectilele doar pentru randare; lovitura o decide serverul.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Defense = require(Shared.Config.Defense)
local World = require(Shared.Config.World)
local Slipper = require(Shared.Domain.Slipper)
local RateLimiter = require(Shared.Domain.RateLimiter)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)
local DayNightService = require(script.Parent.DayNightService)
local RaidService = require(script.Parent.RaidService)
local Messenger = require(script.Parent.Messenger)

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
	thrower: Player?,
	origin: Vector3,
	velocity: Vector3,
	params: ProjectileParams,
	age: number,
	last: Vector3,
	pierces: boolean, -- făcălețul lovește tot ce prinde pe traiectorie
	alreadyHit: { [Player]: boolean },
}

local TARGET_RADIUS = 2.5

local SlipperService = {}

local throwLimiter = RateLimiter.new(6, 4)
local ammoByPlayer: { [Player]: Slipper.Ammo } = {}
local nerviByPlayer: { [Player]: number } = {}
local projectiles: { Projectile } = {}
local nextId = 0

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function maxAmmo(owner: Owner): number
	return Defense.slipper.maxAmmo + (owner.profile.upgrades.ammo or 0)
end

local function isFiniteVector(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 1e6
end

function SlipperService.nervi(player: Player): number
	return nerviByPlayer[player] or 0
end

-- Consumă Nervi; întoarce false dacă nu sunt destui.
function SlipperService.spendNervi(player: Player, amount: number): boolean
	local current = nerviByPlayer[player] or 0
	if current < amount then
		return false
	end
	nerviByPlayer[player] = current - amount
	StateService.markDirty(player)
	return true
end

local function addNervi(player: Player, amount: number)
	nerviByPlayer[player] = math.min((nerviByPlayer[player] or 0) + amount, Defense.nervi.max)
	StateService.markDirty(player)
end

-- Lansează un proiectil care poate lovi intrușii ogrăzii `owner`.
function SlipperService.launch(
	owner: Owner,
	thrower: Player?,
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
		throwerUserId = if thrower then thrower.UserId else 0,
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

local function applyHit(projectile: Projectile, victim: Player, root: BasePart)
	projectile.alreadyHit[victim] = true
	local params = projectile.params
	RaidService.onHit(
		victim,
		knockbackFor(projectile.owner, root.Position, params.knockbackSpeed),
		params.stunSeconds
	)
	local thrower = projectile.thrower
	if thrower then
		addNervi(thrower, Defense.nervi.perHit)
		projectile.owner.profile.stats.defends += 1
		Messenger.notify(thrower, "notify.Defended", { victim.DisplayName })
	end
	Net.get("Hit"):FireAllClients({
		id = projectile.id,
		kind = projectile.kind,
		position = root.Position,
		victimUserId = victim.UserId,
		plotIndex = projectile.owner.plot.index,
	})
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
		for _, player in Players:GetPlayers() do
			if projectile.alreadyHit[player] or not RaidService.isIntruder(player, projectile.owner) then
				continue
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
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
				applyHit(projectile, player, root)
				if not projectile.pierces then
					finished = true
					break
				end
			end
		end
		projectile.last = position
		if finished then
			table.remove(projectiles, index)
		end
	end
end

local function onThrow(player: Player, target: unknown, kind: unknown)
	if typeof(target) ~= "Vector3" or not isFiniteVector(target :: Vector3) then
		return
	end
	if kind ~= "Slipper" and kind ~= "RollingPin" then
		return
	end
	if not throwLimiter:allow(player.UserId, os.clock()) or RaidService.isStunned(player) then
		return
	end
	local owner = PlotService.getOwner(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not owner or not root then
		return
	end
	local params: ProjectileParams
	if kind == "RollingPin" then
		if not SlipperService.spendNervi(player, Defense.rollingPin.cost) then
			return
		end
		params = Defense.rollingPin
	else
		local ammo = ammoByPlayer[player]
		if not ammo or not Slipper.consume(ammo, now(), maxAmmo(owner), Defense.slipper.regenSeconds) then
			return
		end
		params = Defense.slipper
		StateService.markDirty(player)
	end
	local origin = root.Position + Vector3.new(0, 2, 0)
	SlipperService.launch(owner, player, kind :: string, origin, target :: Vector3, params)
end

function SlipperService.start()
	Net.get("Throw").OnServerEvent:Connect(onThrow)
	PlotService.onOwnerAdded(function(owner)
		local player = owner.player
		if player then
			ammoByPlayer[player] = Slipper.newAmmo(maxAmmo(owner), now())
			nerviByPlayer[player] = 0
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		ammoByPlayer[player] = nil
		nerviByPlayer[player] = nil
		throwLimiter:forget(player.UserId)
	end)
	DayNightService.onPhaseChanged(function(phase)
		if phase == "Day" then
			for player in nerviByPlayer do
				nerviByPlayer[player] = 0
				StateService.markDirty(player)
			end
		end
	end)
	StateService.addProvider(function(player, state)
		local owner = PlotService.getOwner(player)
		local ammo = ammoByPlayer[player]
		if owner and ammo then
			Slipper.updateAmmo(ammo, now(), maxAmmo(owner), Defense.slipper.regenSeconds)
			state.ammo = ammo.ammo
			state.ammoRegenStart = ammo.regenStart
			state.maxAmmo = maxAmmo(owner)
		end
		state.nervi = nerviByPlayer[player] or 0
	end)
	RunService.Heartbeat:Connect(step)
end

return SlipperService
