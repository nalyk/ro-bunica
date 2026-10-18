--!strict
-- Pescuitul: ce iese (șansele afișate în panou) și bara de tensiune la tras.

local Fish = require(script.Parent.Parent.Config.Fish)

export type Reel = { tension: number, progress: number, state: "Reeling" | "Caught" | "Snapped" | "Escaped" }

local Fishing = {}

Fishing.SWEET_LOW = 0.35 -- zona bună a tensiunii
Fishing.SWEET_HIGH = 0.75
local RISE = 0.9 -- pe secundă, cât ții
local FALL = 0.7 -- pe secundă, cât lași
local GAIN = 0.35 -- progres pe secundă în zona bună
local LOSS = 0.12 -- progres pierdut pe secundă când tensiunea e prea mică

local function biting(fish: Fish.Fish, season: string): boolean
	return fish.seasons == nil or table.find(fish.seasons, season) ~= nil
end

-- Probabilitatea fiecărui pește, pe vreme și anotimp (însumează 1)
function Fishing.odds(weather: string, season: string): { [string]: number }
	local weights, total = {}, 0
	for _, fish in Fish.list do
		if biting(fish, season) then
			local w = fish.weight * (if fish.rare and weather == "Rain" then Fish.rainBoost else 1)
			weights[fish.id] = w
			total += w
		end
	end
	local odds = {}
	for id, w in weights do
		odds[id] = w / total
	end
	return odds
end

function Fishing.roll(rng: () -> number, weather: string, season: string): string
	local odds = Fishing.odds(weather, season)
	local roll = rng()
	local last = ""
	for _, fish in Fish.list do
		local p = odds[fish.id]
		if p then
			last = fish.id
			roll -= p
			if roll < 0 then
				return fish.id
			end
		end
	end
	return last
end

function Fishing.newReel(): Reel
	return { tension = 0.3, progress = 0, state = "Reeling" }
end

-- Un pas de `dt`: ții (input) sau lași; peștele trage (`pull` ≥ 0 crește tensiunea)
function Fishing.reel(reel: Reel, input: boolean, dt: number, pull: number): Reel
	if reel.state ~= "Reeling" then
		return reel
	end
	reel.tension += ((if input then RISE else -FALL) + pull) * dt
	if reel.tension >= 1 then
		reel.state = "Snapped"
		return reel
	end
	reel.tension = math.max(0, reel.tension)
	if reel.tension >= Fishing.SWEET_LOW and reel.tension <= Fishing.SWEET_HIGH then
		reel.progress += GAIN * dt
	elseif reel.tension < Fishing.SWEET_LOW then
		reel.progress = math.max(0, reel.progress - LOSS * dt)
	end
	if reel.progress >= 1 then
		reel.state = "Caught"
	end
	return reel
end

-- Smuciturile peștelui, deterministe pe seed (serverul și clientul simulează la fel)
function Fishing.pulls(seed: number, steps: number): { number }
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local list = {}
	local burst = 0
	for _ = 1, steps do
		state = (state * 48271) % 2147483647
		local r = (state - 1) / 2147483646
		if burst <= 0 and r < 0.06 then
			burst = 6 -- o smucitură de 0,6 s
		end
		table.insert(list, if burst > 0 then 0.6 else 0)
		burst -= 1
	end
	return list
end

return Fishing
