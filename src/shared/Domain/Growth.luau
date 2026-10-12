--!strict
-- Creșterea plantelor. Creșterea se acumulează în secunde, ca să suporte accelerări (ploaie, îngrășământ).

local Config = script.Parent.Parent.Config
local Creatures = require(Config.Creatures)
local Sizes = require(Config.Sizes)
local RandomUtil = require(script.Parent.Random)

export type Plant = {
	seedId: string,
	size: string,
	mutation: string?,
	grown: number,
}

local Growth = {}

function Growth.rollSize(rng: () -> number): string
	local entries = {}
	for _, size in Sizes.list do
		table.insert(entries, { value = size.id, weight = size.weight })
	end
	return RandomUtil.weighted(entries, rng) or Sizes.default
end

function Growth.newPlant(seedId: string, rng: () -> number): Plant
	assert(Creatures.byId[seedId], "Sămânță necunoscută: " .. seedId)
	return { seedId = seedId, size = Growth.rollSize(rng), mutation = nil, grown = 0 }
end

function Growth.requiredSeconds(plant: Plant): number
	local creature = Creatures.byId[plant.seedId]
	return if creature then creature.growSeconds else math.huge
end

-- Avansează creșterea. Întoarce true când planta e gata de eclozare.
function Growth.advance(plant: Plant, dt: number, speed: number): boolean
	plant.grown = math.min(plant.grown + math.max(dt, 0) * math.max(speed, 0), Growth.requiredSeconds(plant))
	return Growth.isReady(plant)
end

function Growth.isReady(plant: Plant): boolean
	return plant.grown >= Growth.requiredSeconds(plant)
end

function Growth.progress(plant: Plant): number
	return math.clamp(plant.grown / Growth.requiredSeconds(plant), 0, 1)
end

function Growth.secondsLeft(plant: Plant, speed: number): number
	local left = Growth.requiredSeconds(plant) - plant.grown
	return math.max(left, 0) / math.max(speed, 1e-6)
end

return Growth
