--!strict
-- Evenimentele săptămânale: „Bunica se supără” (sâmbătă, cu o oră înaintea update-ului).
-- Vremea exclusivă, ploaie de papuci din cer peste hoții care cară creaturi și o sămânță exclusivă
-- care se poate cumpăra doar online, cât ține evenimentul.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local LiveEventsConfig = require(Shared.Config.LiveEvents)
local Defense = require(Shared.Config.Defense)
local GameState = require(Shared.GameState)
local LiveEvents = require(Shared.Domain.LiveEvents)
local WeatherService = require(script.Parent.WeatherService)
local ShopService = require(script.Parent.ShopService)
local RaidService = require(script.Parent.RaidService)
local SlipperService = require(script.Parent.SlipperService)
local Messenger = require(script.Parent.Messenger)
local Actors = require(script.Parent.Parent.Actors)

type Running = {
	event: LiveEventsConfig.LiveEvent,
	endsAt: number,
	nextWeatherAt: number,
	nextRainAt: number,
	forced: boolean,
}

local TICK = 1
local SKY_HEIGHT = 45

local LiveEventService = {}

local running: Running? = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function begin(event: LiveEventsConfig.LiveEvent, endsAt: number, forced: boolean)
	local t = now()
	running = { event = event, endsAt = endsAt, nextWeatherAt = t, nextRainAt = t, forced = forced }
	local exclusive = LiveEvents.exclusiveFor(event.exclusives, t)
	ShopService.setExclusive(exclusive)
	GameState.set("LiveEvent", event.id)
	GameState.set("LiveEventEndsAt", endsAt)
	Messenger.announce("announce.LiveStart", { Messenger.key("creature." .. tostring(exclusive)) })
end

local function finish()
	running = nil
	ShopService.setExclusive(nil)
	GameState.set("LiveEvent", "")
	Messenger.announce("announce.LiveEnd")
end

-- Papuci din cer peste fiecare hoț care cară o creatură
local function slipperRain()
	for actor, owner in RaidService.carriers() do
		local root = Actors.root(actor)
		if root then
			local offset = Vector3.new(math.random(-6, 6), SKY_HEIGHT, math.random(-6, 6))
			SlipperService.launch(owner, nil, "SkySlipper", root.Position + offset, root.Position, {
				speed = 70,
				gravity = Defense.slipper.gravity,
				hitRadius = Defense.slipper.hitRadius + 1,
				maxRange = 80,
				maxLifetime = 2.5,
				stunSeconds = Defense.slipper.stunSeconds,
				knockbackSpeed = Defense.slipper.knockbackSpeed,
			})
		end
	end
end

local function tick()
	local t = now()
	local current = running
	if current then
		if t >= current.endsAt then
			finish()
			return
		end
		if t >= current.nextWeatherAt then
			WeatherService.trigger(current.event.weather, true)
			current.nextWeatherAt = t + current.event.weatherEverySeconds
		end
		if t >= current.nextRainAt then
			slipperRain()
			current.nextRainAt = t + current.event.slipperRainEverySeconds
		end
		return
	end
	for _, event in LiveEventsConfig.list do
		local active, endsAt = LiveEvents.activeWindow(event, t)
		if active then
			begin(event, endsAt, false)
			return
		end
	end
end

-- Pornește un eveniment acum (teste, comenzi de admin).
function LiveEventService.forceStart(eventId: string, seconds: number)
	local event = LiveEventsConfig.byId[eventId]
	if event then
		begin(event, now() + seconds, true)
	end
end

function LiveEventService.stop()
	if running then
		finish()
	end
end

function LiveEventService.current(): string?
	return if running then running.event.id else nil
end

function LiveEventService.start()
	GameState.set("LiveEvent", "")
	while true do
		task.wait(TICK)
		local ok, err = pcall(tick :: any)
		if not ok then
			warn("[LiveEventService] tick a eșuat:", err)
		end
	end
end

return LiveEventService
