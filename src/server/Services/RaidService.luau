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
local PlotService = require(script.Parent.PlotService)
local CreatureService = require(script.Parent.CreatureService)
local StateService = require(script.Parent.StateService)
local DayNightService = require(script.Parent.DayNightService)
local Messenger = require(script.Parent.Messenger)
local Actors = require(script.Parent.Parent.Actors)

type Owner = PlotService.Owner
type Actor = Actors.Actor

type Carry = {
	owner: Owner,
	key: string,
	uid: string,
	model: Model,
	walkSpeed: number,
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

function RaidService.carryOf(actor: Actor): Owner?
	local carry = carries[actor]
	return if carry then carry.owner else nil
end

function RaidService.isStunned(actor: Actor): boolean
	return (stunnedUntil[actor] or 0) > now()
end

-- Este jucătorul un intrus pentru acest proprietar? (ținta legitimă a papucului)
function RaidService.isIntruder(actor: Actor, owner: Owner): boolean
	if owner.actor == actor then
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
		humanoid.WalkSpeed = carry.walkSpeed
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

local function attachToCharacter(model: Model, root: BasePart)
	local primary = model.PrimaryPart :: BasePart
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = true
			descendant.CanCollide = false
			if descendant ~= primary then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primary
				weld.Part1 = descendant
				weld.Parent = descendant
			end
		end
	end
	local height = model:GetExtentsSize().Y
	model:PivotTo(root.CFrame * CFrame.new(0, CARRY_HEIGHT + height / 2, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = primary
	weld.Parent = primary
	model.Parent = root.Parent
end

-- Încearcă să înceapă un furt. Apelat de prompt (jucători) sau direct (boți, teste).
function RaidService.tryStart(actor: Actor, owner: Owner, key: string)
	local thief = PlotService.getOwnerOfActor(actor)
	local root = rootOf(actor)
	local humanoid = humanoidOf(actor)
	local model = CreatureService.modelAt(owner, key)
	local record = owner.profile.pedestals[key]
	if not thief or not root or not humanoid or humanoid.Health <= 0 or not model or not record then
		return
	end
	local ok, reason = Raid.canSteal({
		phase = DayNightService.phase(),
		isOwnPlot = thief == owner,
		ownerPresent = owner.plot.owner == owner,
		thiefCarrying = carries[actor] ~= nil,
		thiefStunned = RaidService.isStunned(actor),
		ownerShieldUntil = owner.shieldUntil,
		-- În Studio, protecția jucătorilor noi e dezactivată ca să poată fi testate furturile
		ownerPlaySeconds = if RunService:IsStudio() then math.huge else owner.profile.playSeconds,
		ownerIsNpc = owner.kind == "Npc",
		now = now(),
		distance = (root.Position - model:GetPivot().Position).Magnitude,
		creatureOnPedestal = not carriedUids[record.uid],
	})
	if not ok then
		if reason == "NotNight" or reason == "Shielded" or reason == "NewPlayer" then
			Messenger.notify(actor.player, "notify." .. reason)
		end
		return
	end

	CreatureService.setHidden(owner, key, true)
	local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt:Destroy()
	end
	attachToCharacter(model, root)

	local creature = Creatures.byId[record.id]
	carries[actor] = {
		owner = owner,
		key = key,
		uid = record.uid,
		model = model,
		walkSpeed = humanoid.WalkSpeed,
		jumpHeight = humanoid.JumpHeight,
		lastPosition = root.Position,
		lastTime = os.clock(),
	}
	carriedUids[record.uid] = true
	humanoid.WalkSpeed = humanoid.WalkSpeed * Raid.carrySpeedMultiplier(creature.rarity)
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
				humanoid.WalkSpeed,
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
function RaidService.onHit(victim: Actor, knockback: Vector3, stunSeconds: number)
	if carries[victim] then
		RaidService.drop(victim)
	end
	stunnedUntil[victim] = now() + stunSeconds
	if victim.player then
		Net.get("Knockback"):FireClient(victim.player, knockback, stunSeconds)
	else
		local root = Actors.root(victim)
		if root then
			root.AssemblyLinearVelocity = knockback
		end
	end
end

-- Verificarea furturilor în curs (rulată pe Heartbeat; expusă pentru teste).
RaidService.checkCarries = checkCarries

function RaidService.start()
	CreatureService.onModelCreated(addPrompt)
	DayNightService.onPhaseChanged(function(phase)
		for prompt in prompts do
			prompt.Enabled = phase == "Night"
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
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= CHECK_INTERVAL then
			elapsed = 0
			checkCarries()
		end
	end)
end

return RaidService
