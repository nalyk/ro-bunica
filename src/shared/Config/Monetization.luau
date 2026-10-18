--!strict
-- Ce se vinde pe Robux (GDD §13): identitate, comoditate și momente sociale; niciodată protecție contra
-- furtului, cutii aleatorii sau presiune de timp. Id-urile sunt cele create în Creator Dashboard.
-- Un produs cu id 0 nu e încă creat și nu apare în magazin.

export type Pass = { key: string, id: number, icon: string, random: boolean? }
export type Product = {
	key: string,
	id: number,
	icon: string,
	kind: "lei" | "fertilizer" | "restock" | "weather",
	weather: string?,
	-- duce la rezultate aleatorii (Domain/Policy): ascuns unde ArePaidRandomItemsRestricted
	random: boolean?,
}

local passes: { Pass } = {
	{ key = "vip", id = 2038238982, icon = "vip" },
	{ key = "doublelei", id = 2037477027, icon = "doublelei", random = true },
	{ key = "goldslipper", id = 2037837048, icon = "goldslipper" },
	{ key = "bigcellar", id = 2039540879, icon = "bigcellar" },
	{ key = "gardener", id = 2036205004, icon = "gardener" },
}

local products: { Product } = {
	{ key = "lei_s", id = 3719054463, icon = "lei_s", kind = "lei", random = true },
	{ key = "lei_m", id = 3719054588, icon = "lei_m", kind = "lei", random = true },
	{ key = "lei_l", id = 3719054681, icon = "lei_l", kind = "lei", random = true },
	{ key = "fertilizer", id = 3719054853, icon = "fertilizer", kind = "fertilizer" },
	{ key = "restock", id = 3719165422, icon = "restock", kind = "restock", random = true },
	{
		key = "weather_gold",
		id = 3719165896,
		icon = "weather_gold",
		kind = "weather",
		random = true,
		weather = "GoldHarvest",
	},
	{
		key = "weather_rainbow",
		id = 3719166385,
		icon = "weather_rainbow",
		kind = "weather",
		random = true,
		weather = "Rainbow",
	},
}

local passByKey: { [string]: Pass } = {}
local passById: { [number]: Pass } = {}
for _, pass in passes do
	passByKey[pass.key] = table.freeze(pass)
	passById[pass.id] = pass
end
local productById: { [number]: Product } = {}
local productByKey: { [string]: Product } = {}
for _, product in products do
	table.freeze(product)
	productByKey[product.key] = product
	if product.id ~= 0 then
		productById[product.id] = product
	end
end

return table.freeze({
	-- abonamentul lunar „Prietenii Bunicii” (Domain/Subscription); id-ul din Dashboard (EXP-…), gol = oprit
	subscription = "EXP-4024965016297013811",
	passes = table.freeze(passes),
	products = table.freeze(products),
	passByKey = table.freeze(passByKey),
	passById = table.freeze(passById),
	productById = table.freeze(productById),
	productByKey = table.freeze(productByKey),
	-- pachetele de lei: atâtea secunde din venitul curent al ogrăzii, dar cel puțin `min`
	leiPacks = table.freeze({
		lei_s = table.freeze({ seconds = 600, min = 500 }),
		lei_m = table.freeze({ seconds = 3600, min = 5000 }),
		lei_l = table.freeze({ seconds = 6 * 3600, min = 50000 }),
	}),
	vipPedestals = 4,
	bigCellarSlots = 50,
	gardenerBeds = 2,
	doubleLeiMultiplier = 2,
	receiptsKept = 200, -- chitanțe procesate ținute în profil (anti-dublare)
})
