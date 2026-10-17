--!strict
-- Hora: în vatra satului, 3+ jucători care dansează în cerc 4 s cheamă o vreme rară pentru tot serverul.
-- Un ritual de grup care răsplătește jocul împreună (semnal de clasament „co-play”).

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Hora = require(Shared.Config.Hora)
local GameState = require(Shared.GameState)
local Ritual = require(Shared.Domain.Ritual)
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
	local eventId = RandomUtil.weighted(Hora.rewards :: any, math.random) :: string
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
	Net.get("Hora").OnServerEvent:Connect(function(player)
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
