--!strict
-- Colecția din Caietul Bunicii: o intrare = o creatură cu o mutație (sau fără). Prima descoperire dă lei;
-- pragurile dau venit permanent, iar la `secretAt` intrări Rețeta Secretă prinde viață.

local Config = script.Parent.Parent.Config
local Creatures = require(Config.Creatures)
local Mutations = require(Config.Mutations)
local Notebook = require(Config.Notebook)
local Economy = require(script.Parent.Economy)

type CreatureRecord = { id: string, size: string, mutation: string? }
type Profile = { collection: { [string]: boolean } }

local Collection = {}

function Collection.key(id: string, mutation: string?): string
	return if mutation then id .. ":" .. mutation else id
end

-- Toate intrările posibile, în ordinea din config (creatură, apoi mutațiile ei).
function Collection.entries(): { string }
	local list = {}
	for _, creature in Creatures.list do
		table.insert(list, creature.id)
		for _, mutation in Mutations.list do
			table.insert(list, creature.id .. ":" .. mutation.id)
		end
	end
	return list
end

Collection.TOTAL = #Collection.entries()

-- Pragurile, cu „toate” la final.
function Collection.milestones(): { number }
	local list = table.clone(Notebook.collection.milestones) :: { number }
	if list[#list] < Collection.TOTAL then
		table.insert(list, Collection.TOTAL)
	end
	return list
end

function Collection.count(profile: Profile): number
	local n = 0
	for _ in profile.collection do
		n += 1
	end
	return n
end

-- Câte praguri a atins colecția.
function Collection.reached(count: number): number
	local n = 0
	for _, milestone in Collection.milestones() do
		if count >= milestone then
			n += 1
		end
	end
	return n
end

-- Multiplicatorul de venit din praguri (1 = niciunul).
function Collection.multiplier(profile: Profile): number
	return 1 + Collection.reached(Collection.count(profile)) * Notebook.collection.milestoneBonus
end

-- Leii pentru prima descoperire a unei intrări.
function Collection.reward(id: string, mutation: string?): number
	local price = Economy.sellPrice({ id = id, size = "Normal", mutation = mutation })
	return math.max(math.floor(price * Notebook.collection.rewardShare), Notebook.collection.minReward)
end

export type Discovery = { key: string, lei: number, milestone: number?, secret: boolean }

-- Marchează creatura ca descoperită. Întoarce descoperirea (nouă) sau nil dacă era deja în caiet.
-- `milestone`: pragul atins chiar acum; `secret`: tocmai s-a atins pragul Rețetei Secrete.
function Collection.discover(profile: Profile, record: CreatureRecord): Discovery?
	if not Creatures.byId[record.id] then
		return nil
	end
	local mutation = if record.mutation and Mutations.byId[record.mutation] then record.mutation else nil
	local key = Collection.key(record.id, mutation)
	if profile.collection[key] then
		return nil
	end
	local before = Collection.count(profile)
	profile.collection[key] = true
	local after = before + 1
	local milestone: number? = nil
	for _, value in Collection.milestones() do
		if before < value and after >= value then
			milestone = value
		end
	end
	local secretAt = Notebook.collection.secretAt
	return {
		key = key,
		lei = Collection.reward(record.id, mutation),
		milestone = milestone,
		secret = before < secretAt and after >= secretAt,
	}
end

return Collection
