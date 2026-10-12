--!strict
-- Evenimente meteo pe server: programate sau cumpărate. Aplică mutații plantelor și creaturilor expuse.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Weather = require(Shared.Config.Weather)
local Mutations = require(Shared.Config.Mutations)
local GameState = require(Shared.GameState)
local Mutation = require(Shared.Domain.Mutation)
local RandomUtil = require(Shared.Domain.Random)
local PlotService = require(script.Parent.PlotService)
local CreatureService = require(script.Parent.CreatureService)
local StateService = require(script.Parent.StateService)
local DayNightService = require(script.Parent.DayNightService)
local Messenger = require(script.Parent.Messenger)

type Owner = PlotService.Owner

local WeatherService = {}

local active: Weather.WeatherEvent? = nil
local token = 0 -- fiecare eveniment pornit primește un token; unul nou îl oprește pe cel vechi
local activeUntil = 0

function WeatherService.current(): Weather.WeatherEvent?
	return active
end

function WeatherService.growthSpeed(): number
	return if active then active.growthSpeed else 1
end

local function announceMutation(owner: Owner, creatureId: string, mutationId: string)
	local mutation = Mutations.byId[mutationId]
	Messenger.notify(
		owner.player,
		"notify.Mutated",
		{ Messenger.key("creature." .. creatureId), Messenger.key("mutation." .. mutationId) }
	)
	if mutation and mutation.announce then
		Messenger.announce(
			"announce.Mutation",
			{ owner.name, Messenger.key("mutation." .. mutationId), Messenger.key("creature." .. creatureId) }
		)
	end
end

local function applyTick(event: Weather.WeatherEvent)
	for _, owner in PlotService.owners() do
		if owner.kind ~= "Player" then
			continue
		end
		local changed = false
		for key, plant in owner.profile.beds do
			local result, didChange =
				Mutation.tryApply(plant.mutation, event.mutation, event.plantChancePerTick, math.random)
			if didChange then
				plant.mutation = result
				local bed = owner.plot.geometry.beds[key]
				if bed then
					bed:SetAttribute("Mutation", result)
				end
				changed = true
			end
		end
		for key, record in owner.profile.pedestals do
			local result, didChange =
				Mutation.tryApply(record.mutation, event.mutation, event.creatureChancePerTick, math.random)
			if didChange and result then
				record.mutation = result
				CreatureService.renderKey(owner, key)
				announceMutation(owner, record.id, result)
				changed = true
			end
		end
		if changed then
			CreatureService.refreshShowcase(owner)
			StateService.markDirty(owner.player)
		end
	end
end

-- Pornește un eveniment (programat sau cumpărat). Întoarce false dacă unul e deja activ.
-- Pornește un eveniment. `force` înlocuiește evenimentul activ (Hora, „Bunica se supără”, cumpărare).
function WeatherService.trigger(eventId: string, force: boolean?): boolean
	local event = Weather.byId[eventId]
	if not event or (active and not force) then
		return false
	end
	token += 1
	local myToken = token
	active = event
	activeUntil = Workspace:GetServerTimeNow() + event.durationSeconds
	GameState.set(GameState.Attributes.Weather, event.id)
	GameState.set(GameState.Attributes.WeatherEndsAt, activeUntil)
	Messenger.announce("announce.Weather", { Messenger.key("weather." .. event.id) })
	task.spawn(function()
		while token == myToken and Workspace:GetServerTimeNow() < activeUntil do
			task.wait(Weather.tickSeconds)
			if token ~= myToken then
				return
			end
			local ok, err = pcall(applyTick :: any, event)
			if not ok then
				warn("[WeatherService] tick a eșuat:", err)
			end
		end
		if token == myToken then
			active = nil
			GameState.set(GameState.Attributes.Weather, "")
		end
	end)
	return true
end

local function pickScheduled(): string?
	local phase = DayNightService.phase()
	local entries = {}
	for _, event in Weather.list do
		if event.scheduleWeight > 0 and (event.phase == "Any" or event.phase == phase) then
			table.insert(entries, { value = event.id, weight = event.scheduleWeight })
		end
	end
	return RandomUtil.weighted(entries, math.random)
end

function WeatherService.start()
	GameState.set(GameState.Attributes.Weather, "")
	while true do
		task.wait(math.random(Weather.minGapSeconds, Weather.maxGapSeconds))
		local eventId = pickScheduled()
		if eventId then
			WeatherService.trigger(eventId)
		end
	end
end

return WeatherService
