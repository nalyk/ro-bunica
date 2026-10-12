--!strict
-- Calcule de valoare și venit. Fără efecte secundare.

local Config = script.Parent.Parent.Config
local Creatures = require(Config.Creatures)
local Mutations = require(Config.Mutations)
local Sizes = require(Config.Sizes)
local EconomyConfig = require(Config.Economy)

type CreatureRecord = { id: string, size: string, mutation: string? }

local Economy = {}

-- Venitul pe secundă al unei creaturi, cu mutație și mărime.
function Economy.incomePerSecond(record: CreatureRecord): number
	local creature = Creatures.byId[record.id]
	if not creature then
		return 0
	end
	local size = Sizes.byId[record.size]
	local mutation = if record.mutation then Mutations.byId[record.mutation] else nil
	local sizeMultiplier = if size then size.multiplier else 1
	local mutationMultiplier = if mutation then mutation.multiplier else 1
	return creature.income * sizeMultiplier * mutationMultiplier
end

function Economy.sellPrice(record: CreatureRecord): number
	return math.floor(Economy.incomePerSecond(record) * EconomyConfig.sellMultiplier)
end

-- Multiplicatorul din bonusul de prieteni (1 = fără bonus).
function Economy.friendMultiplier(friendCount: number): number
	local boost = math.min(friendCount * EconomyConfig.friendBoostPerFriend, EconomyConfig.friendBoostMax)
	return 1 + math.max(boost, 0)
end

-- Venitul total pe secundă pentru creaturile expuse.
function Economy.totalIncome(displayed: { [any]: any }, multiplier: number): number
	local total = 0
	for _, record in displayed do
		total += Economy.incomePerSecond(record)
	end
	return total * multiplier
end

-- Leii câștigați cât jucătorul a fost offline.
function Economy.offlineEarnings(incomePerSecond: number, secondsAway: number): number
	if secondsAway <= 0 or incomePerSecond <= 0 then
		return 0
	end
	local seconds = math.min(secondsAway, EconomyConfig.offlineCapSeconds)
	return math.floor(incomePerSecond * seconds * EconomyConfig.offlineRate)
end

-- Formatare scurtă pentru UI: 1.2K, 3.4M, 5B.
function Economy.formatShort(value: number): string
	local abs = math.abs(value)
	local suffixes: { { limit: number, suffix: string } } = {
		{ limit = 1e12, suffix = "T" },
		{ limit = 1e9, suffix = "B" },
		{ limit = 1e6, suffix = "M" },
		{ limit = 1e3, suffix = "K" },
	}
	for _, pair in suffixes do
		if abs >= pair.limit then
			local scaled = value / pair.limit
			local text = if math.abs(scaled) >= 100
				then string.format("%d", math.floor(scaled))
				else string.format("%.1f", math.floor(scaled * 10) / 10)
			text = string.gsub(text, "%.0$", "")
			return text .. pair.suffix
		end
	end
	return tostring(math.floor(value))
end

return Economy
