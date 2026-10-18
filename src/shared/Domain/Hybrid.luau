--!strict
-- Hibrizii: două straturi alăturate cu creaturi cel puțin rare pot da, rar, un hibrid (corpul primei, „pălăria”
-- celei de-a doua), cu nume compus și venit (A + B) × 0,75. Au colecția lor în Caiet.

local Config = script.Parent.Parent.Config
local Creatures = require(Config.Creatures)
local Rarities = require(Config.Rarities)
local HybridNames = require(Config.HybridNames)

local Hybrid = {}

Hybrid.MIN_CHANCE = 0.02
Hybrid.MAX_CHANCE = 0.08

local function order(id: string): number
	local creature = Creatures.byId[id]
	local rarity = creature and Rarities.byId[creature.rarity]
	return if rarity then rarity.order else 0
end

-- Șansa de hibrid la eclozare: 0 sub Rar; 2% la Rar + Rar, până la 8% la rarități mari
function Hybrid.chance(a: string, b: string): number
	local rare = Rarities.byId.Rare.order
	local oa, ob = order(a), order(b)
	if oa < rare or ob < rare then
		return 0
	end
	return math.min(Hybrid.MAX_CHANCE, Hybrid.MIN_CHANCE + 0.01 * ((oa - rare) + (ob - rare)))
end

function Hybrid.name(a: string, b: string, seed: number): string
	local na, nb = HybridNames[a], HybridNames[b]
	if not na or not nb then
		return a .. "-" .. b
	end
	local head = na.heads[seed % #na.heads + 1]
	return head .. "-" .. nb.tail
end

function Hybrid.income(incomeA: number, incomeB: number): number
	return (incomeA + incomeB) * 0.75
end

function Hybrid.key(a: string, b: string): string
	return if a < b then a .. "+" .. b else b .. "+" .. a
end

return Hybrid
