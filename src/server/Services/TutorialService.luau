--!strict
-- Primul minut: hoțul scriptat. Vine pe drum, intră pe poartă, ridică o copie a creaturii
-- (datele jucătorului nu se ating) și fuge încet. Jucătorul aruncă papucul cu ajutor la ochit.
-- Dacă nu nimerește în câteva secunde, Bunica aruncă sigur: gluma de bază se întâmplă oricum.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local World = require(Shared.Config.World)
local Tutorial = require(Shared.Config.Tutorial)
local CreatureBuilder = require(Shared.Visual.CreatureBuilder)
local PlotService = require(script.Parent.PlotService)
local CreatureService = require(script.Parent.CreatureService)
local RaidService = require(script.Parent.RaidService)
local SlipperService = require(script.Parent.SlipperService)
local BunicaService = require(script.Parent.BunicaService)
local Actors = require(script.Parent.Parent.Actors)
local Walker = require(script.Parent.Parent.Ai.Walker)

type Owner = PlotService.Owner
type Actor = Actors.Actor

type Session = {
	owner: Owner,
	thief: Actor?,
	clone: Model?,
	key: string?,
	hitBy: string?, -- "player" | "bunica"
	finished: boolean,
}

local THIEF_NAME = "Hoțomanul"
local CARRY_HEIGHT = 3

local TutorialService = {}

local sessions: { [Owner]: Session } = {}
local thiefSessions: { [Actor]: Session } = {}

local function send(owner: Owner, stage: string, data: { any }?)
	if owner.player then
		Net.get("Tutorial"):FireClient(owner.player, stage, data)
	end
end

local function firstPedestal(owner: Owner): string?
	local keys = {}
	for key in owner.profile.pedestals do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)
	return keys[1]
end

local function cleanup(session: Session, completed: boolean)
	if session.finished then
		return
	end
	session.finished = true
	local owner = session.owner
	if session.clone then
		session.clone:Destroy()
	end
	if session.key and not owner.removing and owner.plot.owner == owner then
		CreatureService.setHidden(owner, session.key, false)
	end
	if owner.actor then
		SlipperService.setAimAssist(owner.actor, nil)
	end
	local thief = session.thief
	if thief then
		RaidService.forceIntruder(thief, nil)
		thiefSessions[thief] = nil
		task.delay(Tutorial.cleanupSeconds, Actors.removeBot, thief)
	end
	if completed then
		owner.profile.tutorialThiefDone = true
		send(owner, "done", { session.hitBy == "player" })
	end
	sessions[owner] = nil
end

-- Rulează scena hoțului pentru o ogradă. Pornit automat pentru jucătorii noi; testele îl apelează direct.
-- `delaySeconds` înlocuiește pragul de timp din config (testele nu așteaptă 25 s).
function TutorialService.run(owner: Owner, delaySeconds: number?)
	if sessions[owner] or owner.profile.tutorialThiefDone then
		return
	end
	local session: Session = { owner = owner, finished = false }
	sessions[owner] = session
	local startedAt = os.clock()

	-- Așteaptă creatura de start pe piedestal și pragul de timp
	local key: string? = nil
	while owner.plot.owner == owner and not owner.removing do
		key = firstPedestal(owner)
		if
			key
			and CreatureService.modelAt(owner, key)
			and os.clock() - startedAt >= (delaySeconds or Tutorial.thiefDelaySeconds)
		then
			break
		end
		task.wait(0.5)
	end
	if not key or owner.plot.owner ~= owner or owner.removing then
		cleanup(session, false)
		return
	end

	local geometry = owner.plot.geometry
	local halfDepth = World.plotSize.Z / 2
	local roadPoint = (geometry.cframe * CFrame.new(-25, 3, -halfDepth - 8)).Position
	local gateOut = (geometry.cframe * CFrame.new(0, 3, -halfDepth - 3)).Position
	local gateIn = (geometry.cframe * CFrame.new(0, 3, -halfDepth + 5)).Position
	local model = CreatureService.modelAt(owner, key) :: Model
	local approach = model:GetPivot().Position + geometry.cframe.LookVector * 4

	local thief = Actors.createBot(THIEF_NAME, CFrame.new(roadPoint))
	session.thief = thief
	thiefSessions[thief] = session
	local humanoid = Actors.humanoid(thief) :: Humanoid
	local root = Actors.root(thief) :: BasePart
	humanoid.WalkSpeed = Tutorial.thiefWalkSpeed
	send(owner, "incoming", { THIEF_NAME })

	local function trace(label: string)
		if RunService:IsStudio() then
			print(
				string.format(
					"[Tutorial] %s: hoț la %.0f studs de creatură (%.0f, %.0f, %.0f)",
					label,
					(root.Position - approach).Magnitude,
					root.Position.X,
					root.Position.Y,
					root.Position.Z
				)
			)
		end
	end
	trace("apare")
	Walker.follow(humanoid, { gateOut, gateIn, Vector3.new(approach.X, gateIn.Y, approach.Z) }, function()
		if owner.removing then
			return true
		end
		return session.finished
	end)
	if session.finished or owner.removing then
		return
	end

	trace("ajunge")
	-- Ridică o copie; originalul doar se ascunde, datele rămân neatinse
	local record = owner.profile.pedestals[key]
	if not record then
		cleanup(session, false)
		return
	end
	session.key = key
	CreatureService.setHidden(owner, key, true)
	local clone =
		CreatureBuilder.build({ id = record.id, size = record.size, mutation = record.mutation }, root.CFrame)
	CreatureBuilder.attachAbove(clone, root, CARRY_HEIGHT)
	session.clone = clone

	RaidService.forceIntruder(thief, owner)
	if owner.actor then
		SlipperService.setAimAssist(owner.actor, function()
			return { root.Position }
		end, Tutorial.aimAssistRadius)
	end
	send(owner, "throw", { THIEF_NAME })

	-- Fuge încet înapoi spre drum
	task.spawn(Walker.follow, humanoid, { gateIn, gateOut, roadPoint }, function()
		return session.hitBy ~= nil or session.finished
	end)

	local deadline = os.clock() + Tutorial.fallbackSeconds
	while not session.hitBy and os.clock() < deadline and not session.finished do
		task.wait(0.1)
	end
	if not session.hitBy and not session.finished then
		BunicaService.throwAt(owner, root, true)
		local fallbackDeadline = os.clock() + 5
		while not session.hitBy and os.clock() < fallbackDeadline and not session.finished do
			task.wait(0.1)
		end
	end
	cleanup(session, session.hitBy ~= nil)
end

function TutorialService.isActive(owner: Owner): boolean
	return sessions[owner] ~= nil
end

-- Hoțul din scena în curs (pentru teste și indicii vizuale).
function TutorialService.thiefOf(owner: Owner): Actor?
	local session = sessions[owner]
	return if session then session.thief else nil
end

-- Scena a ajuns la momentul aruncării?
function TutorialService.isWaitingForThrow(owner: Owner): boolean
	local session = sessions[owner]
	return session ~= nil and session.clone ~= nil and session.hitBy == nil
end

function TutorialService.start()
	RaidService.onActorHit(function(victim, source)
		local session = thiefSessions[victim]
		if session and not session.hitBy then
			session.hitBy = if source.thrower and source.thrower == session.owner.actor
				then "player"
				else "bunica"
			print(
				string.format(
					"[Tutorial] hoțul lovit de %s (%s, %.0f studs)",
					tostring(session.hitBy),
					source.kind,
					source.distance
				)
			)
			if session.clone then
				session.clone:Destroy()
				session.clone = nil
			end
		end
	end)
	PlotService.onOwnerAdded(function(owner)
		if owner.kind == "Player" and not owner.profile.tutorialThiefDone then
			task.spawn(TutorialService.run, owner)
		end
	end)
	PlotService.onOwnerRemoving(function(owner)
		local session = sessions[owner]
		if session then
			cleanup(session, false)
		end
	end)
end

return TutorialService
