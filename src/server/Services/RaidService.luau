--!strict
-- Furtul: ridicarea creaturii, căratul, depunerea în beciul propriu și scăparea ei.
-- Regula anti-duplicare: creatura rămâne în profilul proprietarului până la depunere.
-- Orice eșec (lovitură, ieșire de pe server, viteză imposibilă) o lasă acolo unde era.

local Players = game:GetService("Players")
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

type Owner = PlotService.Owner

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

local carries: { [Player]: Carry } = {}
local carriedUids: { [string]: boolean } = {}
local stunnedUntil: { [Player]: number } = {}
local prompts: { [ProximityPrompt]: boolean } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

function RaidService.isCarried(uid: string): boolean
	return carriedUids[uid] == true
end

function RaidService.isCarrying(player: Player): boolean
	return carries[player] ~= nil
end

function RaidService.carryOf(player: Player): Owner?
	local carry = carries[player]
	return if carry then carry.owner else nil
end

function RaidService.isStunned(player: Player): boolean
	return (stunnedUntil[player] or 0) > now()
end

-- Este jucătorul un intrus pentru acest proprietar? (ținta legitimă a papucului)
function RaidService.isIntruder(player: Player, owner: Owner): boolean
	if owner.player == player then
		return false
	end
	local carry = carries[player]
	if carry and carry.owner == owner then
		return true
	end
	if DayNightService.phase() ~= "Night" then
		return false
	end
	local root = rootOf(player)
	return root ~= nil and PlotService.plotAt(root.Position) == owner.plot
end

local function restoreHumanoid(player: Player, carry: Carry)
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.WalkSpeed = carry.walkSpeed
		humanoid.JumpHeight = carry.jumpHeight
	end
end

local function endCarry(player: Player): Carry?
	local carry = carries[player]
	if not carry then
		return nil
	end
	carries[player] = nil
	carriedUids[carry.uid] = nil
	restoreHumanoid(player, carry)
	carry.model:Destroy()
	return carry
end

-- Creatura scapă și se întoarce pe piedestal (dacă proprietarul mai e în ogradă).
function RaidService.drop(player: Player)
	local carry = endCarry(player)
	if carry and carry.owner.plot.owner == carry.owner and not carry.owner.removing then
		CreatureService.setHidden(carry.owner, carry.key, false)
	end
end

local function complete(player: Player, thief: Owner)
	local carry = carries[player]
	if not carry then
		return
	end
	local owner = carry.owner
	local record = owner.profile.pedestals[carry.key]
	if not record or record.uid ~= carry.uid then
		RaidService.drop(player)
		return
	end
	-- Verificăm locul la hoț înainte să mutăm ceva
	if not Inventory.freePedestal(thief.profile) and not Inventory.cellarHasRoom(thief.profile) then
		Messenger.notify(player, "notify.Full")
		RaidService.drop(player)
		return
	end
	endCarry(player)
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
	StateService.markDirty(player)
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

local function tryStart(player: Player, owner: Owner, key: string)
	local thief = PlotService.getOwner(player)
	local root = rootOf(player)
	local humanoid = humanoidOf(player)
	local model = CreatureService.modelAt(owner, key)
	local record = owner.profile.pedestals[key]
	if not thief or not root or not humanoid or humanoid.Health <= 0 or not model or not record then
		return
	end
	local ok, reason = Raid.canSteal({
		phase = DayNightService.phase(),
		isOwnPlot = thief == owner,
		ownerPresent = owner.plot.owner == owner,
		thiefCarrying = carries[player] ~= nil,
		thiefStunned = RaidService.isStunned(player),
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
			Messenger.notify(player, "notify." .. reason)
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
	carries[player] = {
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
		tryStart(player, owner, key)
	end)
end

local function checkCarries()
	for player, carry in carries do
		local root = rootOf(player)
		local humanoid = humanoidOf(player)
		local thief = PlotService.getOwner(player)
		if
			not root
			or not humanoid
			or humanoid.Health <= 0
			or not thief
			or carry.owner.plot.owner ~= carry.owner
		then
			RaidService.drop(player)
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
				RaidService.drop(player)
				continue
			end
		end
		if (position - thief.plot.geometry.deposit.Position).Magnitude <= RaidConfig.depositRadius then
			complete(player, thief)
		end
	end
end

-- Apelat de papuc și de Bunica: scapă creatura, amețește și aruncă jucătorul.
function RaidService.onHit(victim: Player, knockback: Vector3, stunSeconds: number)
	if carries[victim] then
		RaidService.drop(victim)
	end
	stunnedUntil[victim] = now() + stunSeconds
	Net.get("Knockback"):FireClient(victim, knockback, stunSeconds)
end

function RaidService.start()
	CreatureService.onModelCreated(addPrompt)
	DayNightService.onPhaseChanged(function(phase)
		for prompt in prompts do
			prompt.Enabled = phase == "Night"
		end
	end)
	PlotService.onOwnerRemoving(function(owner)
		for player, carry in carries do
			-- Proprietarul pleacă: creatura cărată rămâne a lui. Hoțul pleacă: scapă ce căra.
			if carry.owner == owner or player == owner.player then
				RaidService.drop(player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		RaidService.drop(player)
		stunnedUntil[player] = nil
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
