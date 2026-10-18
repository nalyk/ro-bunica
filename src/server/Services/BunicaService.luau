--!strict
-- Bunica fiecărei ogrăzi: personaj cu stări (doarme, bănuitoare, trează, furioasă).
-- Când proprietarul lipsește, apără slab: aruncă un papuc lent și anunțat, iar cocoșul dă alarma.
-- Furia Bunicii (100 Nervi): Bunica iese de pe prispă și urmărește singură hoții câteva secunde.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Defense = require(Shared.Config.Defense)
local RateLimiter = require(Shared.Domain.RateLimiter)
local Upgrades = require(Shared.Domain.Upgrades)
local PlotService = require(script.Parent.PlotService)
local RaidService = require(script.Parent.RaidService)
local SlipperService = require(script.Parent.SlipperService)
local FamilyService = require(script.Parent.FamilyService)
local DayNightService = require(script.Parent.DayNightService)
local BunicaLines = require(Shared.Config.BunicaLines)
local LinePicker = require(Shared.Domain.LinePicker)
local Actors = require(script.Parent.Parent.Actors)
local Rig = require(script.Parent.Parent.Ai.Rig)
local SculptedRig = require(script.Parent.Parent.Ai.SculptedRig)

type Actor = Actors.Actor

type Owner = PlotService.Owner

type BunicaState = "Sleeping" | "Suspicious" | "Awake" | "Watching" | "Rage"

type Bunica = {
	rig: Model,
	humanoid: Humanoid,
	root: BasePart,
	head: BasePart,
	stateLabel: TextLabel,
	home: CFrame,
	suspicion: number,
	nextThrowAt: number,
	rageUntil: number,
	lastAlarmAt: number,
	hadIntruders: boolean,
	lastHitAt: { [Actor]: number },
	lastLine: string?,
	lastLineAt: number,
	lastLineGap: number, -- cât trebuie să treacă după replica de acum (vocea lungă nu e întreruptă)
	signatureSaid: boolean, -- replica semnătură, o dată pe noapte
}

local TICK = 0.2
local ALARM_COOLDOWN = 10
local RAGE_HIT_COOLDOWN = 1

local STATE_ICONS: { [string]: string } = {
	Sleeping = "💤",
	Suspicious = "❓",
	Awake = "❗",
	Watching = "👀",
	Rage = "😡",
}

local BunicaService = {}

-- Cât de departe vede Bunica (1 = normal). Ceața o scade la jumătate (Happenings/Ceata).
local sightMultiplier = 1

function BunicaService.setSight(multiplier: number)
	sightMultiplier = math.clamp(multiplier, 0.1, 2)
end

function BunicaService.sight(): number
	return sightMultiplier
end

local bunicas: { [number]: Bunica } = {} -- după indexul ogrăzii
local enabled = true

-- Pornește sau oprește apărarea automată a Bunicilor (teste, tutorial).
function BunicaService.setEnabled(value: boolean)
	enabled = value
end
local rageLimiter = RateLimiter.new(2, 0.5)

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function finishRig(rig: Model, humanoid: Humanoid, root: BasePart, head: BasePart, home: CFrame): Bunica
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(60, 60)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Text = STATE_ICONS.Sleeping
	label.Parent = billboard

	rig:PivotTo(home * CFrame.new(0, 2.5, 0))
	root.Anchored = true
	rig.Parent = Workspace
	return {
		rig = rig,
		humanoid = humanoid,
		root = root,
		head = head,
		stateLabel = label,
		home = home,
		suspicion = 0,
		nextThrowAt = 0,
		rageUntil = 0,
		lastAlarmAt = -math.huge,
		hadIntruders = false,
		lastHitAt = {},
		lastLine = nil,
		lastLineAt = -math.huge,
		lastLineGap = BunicaLines.minGapSeconds,
		signatureSaid = false,
	}
end

-- Bunica sculptată (art/: concept Codex → TRELLIS.2 → tăiată în corp, cap, brațe), pe rig-ul comun
-- (Ai/SculptedRig). Fața e pictată în textură (fără fața 2D).
local function buildSculpted(home: CFrame): (Model?, Humanoid?, BasePart?, BasePart?)
	-- `home` e orientat pentru rig-ul R15 vechi (rotit 180°); modelul sculptat privește spre -Z, deci îl
	-- întoarcem ca să stea cu fața spre drum (verificat în galeria playtest-ului). Rădăcina rămâne pe `home`.
	local built = SculptedRig.build(
		"char.Bunica",
		"Bunica",
		home * CFrame.Angles(0, math.pi, 0),
		home * CFrame.new(0, 2.5, 0)
	)
	if not built then
		return nil
	end
	return built.rig, built.humanoid, built.root, built.head
end

local function buildRig(home: CFrame): Bunica
	local sRig, sHumanoid, sRoot, sHead = buildSculpted(home)
	if sRig and sHumanoid and sRoot and sHead then
		return finishRig(sRig, sHumanoid, sRoot, sHead, home)
	end
	local description = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(234, 192, 160)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = Color3.fromRGB(40, 40, 70) -- vestă închisă
	description.LeftLegColor = Color3.fromRGB(60, 30, 40) -- fustă lungă
	description.RightLegColor = Color3.fromRGB(60, 30, 40)
	local rig = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	rig.Name = "Bunica"
	Rig.useMotors(rig)
	local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	local head = rig:FindFirstChild("Head") :: BasePart

	-- Basmaua roșie (placeholder până la modelul final)
	local scarf = Instance.new("Part")
	scarf.Name = "Basma"
	scarf.Shape = Enum.PartType.Ball
	scarf.Size = head.Size * 1.15
	scarf.Color = Color3.fromRGB(200, 30, 40)
	scarf.CanCollide = false
	scarf.Massless = true
	-- Spre ceafă și în sus, ca fața Bunicii să rămână la vedere
	scarf.CFrame = head.CFrame * CFrame.new(0, 0.2, 0.3)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = scarf
	weld.Parent = scarf
	scarf.Parent = rig

	return finishRig(rig, humanoid, root, head, home)
end

-- Bunica spune o replică: clientul afișează bula și redă vocea la schimbarea lui LineSeq.
local function say(bunica: Bunica, event: string, force: boolean?)
	local t = os.clock()
	if not force and t - bunica.lastLineAt < bunica.lastLineGap then
		return
	end
	local lines = BunicaLines.events[event]
	local line = if lines then LinePicker.pick(lines, bunica.lastLine, math.random) else nil
	if not line then
		return
	end
	bunica.lastLine = line
	bunica.lastLineAt = t
	local voice = BunicaLines.voice[BunicaLines.voiceFallback][line]
	bunica.lastLineGap = math.max(BunicaLines.minGapSeconds, if voice then voice.seconds + 0.4 else 0)
	bunica.rig:SetAttribute("Line", line)
	bunica.rig:SetAttribute("LineSeq", ((bunica.rig:GetAttribute("LineSeq") :: number?) or 0) + 1)
end

-- O stare scurtă peste starea de bază (de exemplu „Celebrate”), citită de animatorul de pe client.
local function setMood(bunica: Bunica, mood: string, seconds: number)
	bunica.rig:SetAttribute("Mood", mood)
	local seq = ((bunica.rig:GetAttribute("MoodSeq") :: number?) or 0) + 1
	bunica.rig:SetAttribute("MoodSeq", seq)
	task.delay(seconds, function()
		if bunica.rig:GetAttribute("MoodSeq") == seq then
			bunica.rig:SetAttribute("Mood", "")
		end
	end)
end

local function setState(bunica: Bunica, state: BunicaState)
	local previous = bunica.rig:GetAttribute("State")
	if previous ~= state then
		bunica.rig:SetAttribute("State", state)
		bunica.stateLabel.Text = STATE_ICONS[state]
		if state == "Suspicious" then
			say(bunica, "Spot")
		elseif state == "Awake" then
			if not bunica.signatureSaid then
				bunica.signatureSaid = true
				say(bunica, "Signature", true)
			else
				say(bunica, "Wake")
			end
		elseif state == "Rage" then
			say(bunica, "Rage", true)
		end
	end
end

-- Masca de Malanca (Iarna): Bunica nu-l recunoaște pe purtător o vreme
local disguisedUntil: { [Actor]: number } = {}

function BunicaService.disguise(actor: Actor, seconds: number)
	disguisedUntil[actor] = os.clock() + seconds
end

function BunicaService.isDisguised(actor: Actor): boolean
	return (disguisedUntil[actor] or 0) > os.clock()
end

local function intrudersOf(owner: Owner): { { actor: Actor, root: BasePart } }
	local list = {}
	for _, actor in Actors.all() do
		if RaidService.isIntruder(actor, owner) and not BunicaService.isDisguised(actor) then
			local root = Actors.root(actor)
			if root then
				table.insert(list, { actor = actor, root = root })
			end
		end
	end
	return list
end

-- Proprietarul sau cineva din familia lui e în ogradă, aproape de prispă?
local function ownerNearby(owner: Owner, bunica: Bunica): boolean
	for _, member in FamilyService.familyOwners(owner) do
		local root = if member.actor then Actors.root(member.actor) else nil
		if
			root
			and (root.Position - bunica.home.Position).Magnitude <= Defense.bunicaNpc.ownerNearbyRange
			and PlotService.plotAt(root.Position) == owner.plot
		then
			return true
		end
	end
	return false
end

-- `perfect` = aruncare sigură (tutorial): rapidă, fără eroare, cu anticipare completă.
local function throwAt(owner: Owner, bunica: Bunica, targetRoot: BasePart, perfect: boolean?)
	local config = Defense.bunicaNpc
	setState(bunica, "Awake")
	bunica.rig:SetAttribute("Windup", true)
	task.delay(config.windupSeconds, function()
		bunica.rig:SetAttribute("Windup", false)
		if owner.plot.owner ~= owner or not targetRoot.Parent then
			return
		end
		local origin = bunica.root.Position + Vector3.new(0, 2, 0)
		local speed = if perfect then Defense.slipper.speed else config.throwSpeed
		local distance = (targetRoot.Position - origin).Magnitude
		local flightTime = distance / speed
		-- Bunica obișnuită anticipează doar pe jumătate și greșește puțin: hoțul se poate feri
		local lead = targetRoot.AssemblyLinearVelocity * flightTime * (if perfect then 1 else 0.5)
		local errorOffset = if perfect
			then Vector3.zero
			else Vector3.new(
				(math.random() * 2 - 1) * config.aimErrorStuds,
				0,
				(math.random() * 2 - 1) * config.aimErrorStuds
			)
		SlipperService.launch(owner, nil, "BunicaSlipper", origin, targetRoot.Position + lead + errorOffset, {
			speed = speed,
			gravity = Defense.slipper.gravity,
			hitRadius = Defense.slipper.hitRadius + (if perfect then 1.5 else 0),
			maxRange = config.sightRange * sightMultiplier + 15,
			maxLifetime = 3,
			stunSeconds = Defense.slipper.stunSeconds,
			knockbackSpeed = Defense.slipper.knockbackSpeed,
		})
	end)
end

-- Bunica ograzii aruncă la comandă (tutorialul o folosește ca plasă de siguranță).
function BunicaService.throwAt(owner: Owner, targetRoot: BasePart, perfect: boolean?)
	local bunica = bunicas[owner.plot.index]
	if bunica then
		throwAt(owner, bunica, targetRoot, perfect)
	end
end

local function endRage(bunica: Bunica)
	bunica.rageUntil = 0
	bunica.humanoid:MoveTo(bunica.root.Position)
	bunica.rig:PivotTo(bunica.home * CFrame.new(0, 2.5, 0))
	bunica.root.Anchored = true
end

local function tickRage(owner: Owner, bunica: Bunica, intruders: { { actor: Actor, root: BasePart } })
	local config = Defense.rage
	local closest, closestDistance = nil, math.huge
	for _, intruder in intruders do
		local distance = (intruder.root.Position - bunica.root.Position).Magnitude
		if distance < closestDistance then
			closest, closestDistance = intruder, distance
		end
	end
	if not closest then
		bunica.humanoid:MoveTo(bunica.home.Position)
		return
	end
	bunica.humanoid:MoveTo(closest.root.Position)
	local lastHit = bunica.lastHitAt[closest.actor] or -math.huge
	if closestDistance <= config.hitRadius + 2 and now() - lastHit >= RAGE_HIT_COOLDOWN then
		bunica.lastHitAt[closest.actor] = now()
		local knockback = SlipperService.knockbackFor(owner, closest.root.Position, config.knockbackSpeed)
		RaidService.onHit(closest.actor, knockback, config.stunSeconds, {
			kind = "Rage",
			thrower = nil,
			owner = owner,
			distance = closestDistance,
		})
		Net.get("Hit"):FireAllClients({
			id = 0,
			kind = "Rage",
			position = closest.root.Position,
			victimUserId = closest.actor.id,
			plotIndex = owner.plot.index,
		})
	end
end

local function tick(dt: number)
	local config = Defense.bunicaNpc
	local t = now()
	for _, plot in PlotService.plots do
		local owner = plot.owner
		local bunica = bunicas[plot.index]
		if not owner or not bunica then
			continue
		end
		local intruders = intrudersOf(owner)

		-- Alarma cocoșului pentru proprietar
		local hasIntruders = #intruders > 0
		if
			hasIntruders
			and not bunica.hadIntruders
			and owner.player
			and t - bunica.lastAlarmAt >= ALARM_COOLDOWN
		then
			bunica.lastAlarmAt = t
			Net.get("Alarm"):FireClient(owner.player, plot.index)
		end
		bunica.hadIntruders = hasIntruders

		if bunica.rageUntil > t then
			setState(bunica, "Rage")
			tickRage(owner, bunica, intruders)
			continue
		elseif bunica.rageUntil ~= 0 then
			endRage(bunica)
		end

		if ownerNearby(owner, bunica) then
			bunica.suspicion = math.max(bunica.suspicion - config.suspicionDecayPerSecond * dt, 0)
			setState(bunica, if hasIntruders then "Watching" else "Sleeping")
			continue
		end

		local visible: BasePart? = nil
		for _, intruder in intruders do
			if
				(intruder.root.Position - bunica.home.Position).Magnitude
				<= config.sightRange * sightMultiplier
			then
				visible = intruder.root
				break
			end
		end
		if visible then
			local sharp = Upgrades.suspicionMultiplier(owner.profile) -- îmbunătățirea „Bunica mai ageră”
			bunica.suspicion = math.min(bunica.suspicion + config.suspicionPerSecond * sharp * dt, 1)
		else
			bunica.suspicion = math.max(bunica.suspicion - config.suspicionDecayPerSecond * dt, 0)
		end

		if visible and bunica.suspicion >= 1 then
			if t >= bunica.nextThrowAt then
				bunica.nextThrowAt = t + config.throwIntervalSeconds
				throwAt(owner, bunica, visible)
			end
		elseif bunica.suspicion > 0 then
			setState(bunica, "Suspicious")
		else
			setState(bunica, "Sleeping")
		end
	end
end

local function onRage(player: Player)
	if not rageLimiter:allow(player.UserId, os.clock()) then
		return
	end
	local owner = PlotService.getOwner(player)
	local bunica = owner and bunicas[owner.plot.index]
	if not owner or not bunica or bunica.rageUntil > now() then
		return
	end
	if not SlipperService.spendNervi(Actors.forPlayer(player), Defense.rage.cost) then
		return
	end
	bunica.rageUntil = now() + Defense.rage.durationSeconds
	bunica.lastHitAt = {}
	bunica.root.Anchored = false
	bunica.humanoid.WalkSpeed = Defense.rage.bunicaSpeed
	bunica.root:SetNetworkOwner(nil)
end

-- Bunica unei ogrăzi (pentru ținute): modelul și capul
function BunicaService.rigFor(plotIndex: number): (Model?, BasePart?)
	local bunica = bunicas[plotIndex]
	if bunica then
		return bunica.rig, bunica.head
	end
	return nil, nil
end

function BunicaService.start()
	for _, plot in PlotService.plots do
		local bunica = buildRig(plot.geometry.bunicaCFrame)
		bunica.rig.Parent = plot.geometry.model
		bunicas[plot.index] = bunica
	end
	PlotService.onOwnerRemoving(function(owner)
		local bunica = bunicas[owner.plot.index]
		if bunica then
			if bunica.rageUntil ~= 0 then
				endRage(bunica)
			end
			bunica.suspicion = 0
			setState(bunica, "Sleeping")
		end
	end)
	Net.get("Rage").OnServerEvent:Connect(onRage)

	-- Bunica reacționează la ce se întâmplă în ograda ei
	RaidService.onActorHit(function(_victim, source)
		local bunica = bunicas[source.owner.plot.index]
		if bunica then
			setMood(bunica, "Celebrate", BunicaLines.celebrateSeconds)
			say(bunica, "Hit", true)
		end
	end)
	SlipperService.onMiss(function(owner, thrower)
		local bunica = bunicas[owner.plot.index]
		if bunica and owner.actor == thrower and math.random() < BunicaLines.missChance then
			say(bunica, "Miss")
		end
	end)
	-- Bun venit abia după ecranul de încărcare (care ține cel puțin 6 s): mai devreme, replica s-ar pierde sub el
	local greeted: { [Player]: boolean } = {}
	Net.get("Greeted").OnServerEvent:Connect(function(player)
		local owner = PlotService.getOwner(player)
		local bunica = owner and bunicas[owner.plot.index]
		if bunica and not greeted[player] then
			greeted[player] = true
			task.delay(1, say, bunica, "Welcome", true)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		greeted[player] = nil
	end)
	DayNightService.onPhaseChanged(function(phase)
		for _, plot in PlotService.plots do
			local bunica = bunicas[plot.index]
			if bunica then
				bunica.signatureSaid = false
				if phase == "Day" and plot.owner and plot.owner.kind == "Player" then
					say(bunica, "Dawn", true)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		rageLimiter:forget(player.UserId)
	end)
	while true do
		local dt = task.wait(TICK)
		if not enabled then
			continue
		end
		local ok, err = pcall(tick :: any, dt)
		if not ok then
			warn("[BunicaService] tick a eșuat:", err)
		end
	end
end

return BunicaService
