--!strict
-- Hora: în vatra satului, 3+ jucători care dansează în cerc 4 s cheamă o vreme rară pentru tot serverul.
-- Un ritual de grup care răsplătește jocul împreună (semnal de clasament „co-play”).

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Hora = require(Shared.Config.Hora)
local GameState = require(Shared.GameState)
local Ritual = require(Shared.Domain.Ritual)
local Rhythm = require(Shared.Domain.Rhythm)
local RandomUtil = require(Shared.Domain.Random)
local RateLimiter = require(Shared.Domain.RateLimiter)
local WeatherService = require(script.Parent.WeatherService)
local PlotService = require(script.Parent.PlotService)
local Messenger = require(script.Parent.Messenger)
local Actors = require(script.Parent.Parent.Actors)
local Badges = require(script.Parent.Parent.Badges)
local Progress = require(script.Parent.Parent.Progress)

type Actor = Actors.Actor

local TICK = 0.25

local HoraService = {}

local dancingUntil: { [Actor]: number } = {}
local ritualState: Ritual.State = {}
local readyAt = 0
local limiter = RateLimiter.new(4, 1)

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function setAttribute(actor: Actor, value: boolean)
	local character = Actors.characterOf(actor)
	if character then
		character:SetAttribute("Dancing", value)
	end
end

-- Pornește (sau prelungește) dansul unui actor.
function HoraService.setDancing(actor: Actor, seconds: number?)
	dancingUntil[actor] = now() + (seconds or Hora.danceSeconds)
	setAttribute(actor, true)
end

function HoraService.stopDancing(actor: Actor)
	dancingUntil[actor] = nil
	setAttribute(actor, false)
end

-- Hora pe ritm: pașii pe bătaie (o bătaie la 0,5 s, după ceasul serverului). Cine face 4 pași buni la rând
-- are seria; dacă toți din cerc o au, „cercul perfect” cheamă vremea cea mai rară.
local STEP_BEAT = 0.5
local PERFECT_STREAK = 4
local streaks: { [Actor]: number } = {}
local stepLimiter = RateLimiter.new(8, 1)

function HoraService.step(actor: Actor, pressTime: number): string
	if not dancingUntil[actor] then
		return "Ratat"
	end
	local pressed = math.clamp(pressTime, now() - 0.35, now())
	local beat = math.floor(pressed / STEP_BEAT + 0.5) * STEP_BEAT
	local judgement = Rhythm.judge(beat, pressed)
	streaks[actor] = if judgement == "Ratat" then 0 else (streaks[actor] or 0) + 1
	return judgement
end

function HoraService.streak(actor: Actor): number
	return streaks[actor] or 0
end

-- Pentru teste: cine dansează acum, câți sunt în cerc, de când se ține ritualul
function HoraService.debugState(): { [string]: any }
	local list = {}
	for actor, untilTime in dancingUntil do
		local root = Actors.root(actor)
		table.insert(
			list,
			string.format(
				"%s:%.0f s:%s",
				actor.name,
				untilTime - now(),
				if root then string.format("(%.0f,%.0f)", root.Position.X, root.Position.Z) else "fără corp"
			)
		)
	end
	return { dancers = list, readyIn = readyAt - now(), since = ritualState.since }
end

function HoraService.readyAt(): number
	return readyAt
end

-- Pentru teste: ritualul poate porni imediat.
function HoraService.resetCooldown()
	readyAt = 0
	GameState.set("HoraReadyAt", 0)
end

local function tick()
	local t = now()
	local dancers: { Ritual.Dancer } = {}
	for actor, untilTime in dancingUntil do
		local root = Actors.root(actor)
		if untilTime < t or not actor.alive or not root then
			HoraService.stopDancing(actor)
		else
			table.insert(dancers, { id = actor.id, position = root.Position })
		end
	end
	if t < readyAt then
		return
	end
	local done, ids = Ritual.update(ritualState, dancers, t, {
		center = Hora.center,
		radius = Hora.radius,
		minDancers = Hora.minDancers,
		holdSeconds = Hora.holdSeconds,
	})
	if not done then
		return
	end
	local perfect = #ids > 0
	for actor in dancingUntil do
		if table.find(ids, actor.id) and (streaks[actor] or 0) < PERFECT_STREAK then
			perfect = false
		end
	end
	local eventId = if perfect
		then "Rainbow"
		else RandomUtil.weighted(Hora.rewards :: any, math.random) :: string
	WeatherService.trigger(eventId, true)
	readyAt = t + Hora.cooldownSeconds
	GameState.set("HoraReadyAt", readyAt)
	Messenger.announce("announce.Hora", { tostring(#ids), Messenger.key("weather." .. eventId) })
	for actor in dancingUntil do
		if table.find(ids, actor.id) then
			Badges.award(actor.player, "hora")
		end
	end
end

function HoraService.start()
	GameState.set("HoraReadyAt", 0)
	Net.get("Hora").OnServerEvent:Connect(function(player, action, pressTime)
		if action == "step" and typeof(pressTime) == "number" then
			if not stepLimiter:allow(player.UserId, os.clock()) then
				return
			end
			local actor = Actors.forPlayer(player)
			if actor then
				HoraService.step(actor, pressTime)
			end
			return
		end
		if not limiter:allow(player.UserId, os.clock()) then
			return
		end
		local actor = Actors.forPlayer(player)
		local root = Actors.root(actor)
		if not root then
			return
		end
		local flat = Vector3.new(root.Position.X - Hora.center.X, 0, root.Position.Z - Hora.center.Z)
		if flat.Magnitude > Hora.radius * 1.5 then
			Messenger.notify(player, "hora.goToWell")
			return
		end
		HoraService.setDancing(actor)
		Progress.emit(PlotService.getOwner(player), "hora")
	end)
	Actors.onRemoving(function(actor)
		dancingUntil[actor] = nil
		streaks[actor] = nil
	end)
	while true do
		task.wait(TICK)
		local ok, err = pcall(tick :: any)
		if not ok then
			warn("[HoraService] tick a eșuat:", err)
		end
	end
end

return HoraService
