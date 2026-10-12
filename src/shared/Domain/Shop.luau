--!strict
-- Taraba cu semințe: stoc care se reînnoiește periodic.

local Config = script.Parent.Parent.Config
local Creatures = require(Config.Creatures)
local Rarities = require(Config.Rarities)
local EconomyConfig = require(Config.Economy)

export type Stock = { [string]: number }

local Shop = {}

function Shop.restock(rng: () -> number): Stock
	local stock: Stock = {}
	for _, creature in Creatures.list do
		local rarity = Rarities.byId[creature.rarity]
		local count = EconomyConfig.shop.stockPerRarity[creature.rarity]
		if creature.seedPrice and rarity and count and rng() < rarity.shopChance then
			stock[creature.id] = count
		end
	end
	return stock
end

-- Verifică o cumpărare. Întoarce (ok, preț sau motiv).
function Shop.checkPurchase(stock: Stock, seedId: string, lei: number): (boolean, number | string)
	local creature = Creatures.byId[seedId]
	if not creature or not creature.seedPrice then
		return false, "NotForSale"
	end
	if (stock[seedId] or 0) <= 0 then
		return false, "OutOfStock"
	end
	if lei < creature.seedPrice then
		return false, "NotEnoughLei"
	end
	return true, creature.seedPrice
end

-- Momentul următoarei reînnoiri, aliniat la ceasul serverului (toți văd același timer).
function Shop.nextRestockAt(now: number): number
	local period = EconomyConfig.shop.restockSeconds
	return (math.floor(now / period) + 1) * period
end

return Shop
