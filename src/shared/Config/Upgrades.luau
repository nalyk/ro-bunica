--!strict
-- Îmbunătățirile ogrăzii, cumpărate cu lei (GDD §8: „pe lei, nu pe Robux”).
-- Prețul nivelului n (de la 1): baseCost × growth^(n − 1), rotunjit la două cifre semnificative.
-- Piedestalele și straturile se cumpără cât timp ograda mai are loc (World: 20 piedestale, 10 straturi);
-- un game pass care dă piedestale scade câte mai rămân de cumpărat, nu prețul.

export type Upgrade = {
	id: string,
	maxLevel: number,
	baseCost: number,
	growth: number,
	icon: string, -- iconița din art/ui/icons
}

local list: { Upgrade } = {
	{ id = "pedestal", maxLevel = 14, baseCost = 150, growth = 2.1, icon = "pedestal" },
	{ id = "bed", maxLevel = 6, baseCost = 200, growth = 2.6, icon = "seeds" },
	{ id = "cellar", maxLevel = 5, baseCost = 1000, growth = 3, icon = "cellar" },
	{ id = "ammo", maxLevel = 2, baseCost = 5000, growth = 8, icon = "slipper" },
	{ id = "regen", maxLevel = 3, baseCost = 3000, growth = 5, icon = "fastslipper" },
	{ id = "dog", maxLevel = 3, baseCost = 8000, growth = 6, icon = "dog" },
	{ id = "sharp", maxLevel = 3, baseCost = 4000, growth = 5, icon = "sharp" },
}

local byId: { [string]: Upgrade } = {}
for _, upgrade in list do
	byId[upgrade.id] = table.freeze(upgrade)
end

return table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
	cellarPerLevel = 10,
	regenPerLevel = 0.3, -- secunde mai puțin între papuci
	dogSlow = table.freeze({ 0.85, 0.75, 0.65 }), -- viteza hoților în ogradă, pe nivelul lui Grivei
	sharpSuspicion = 0.4, -- bănuiala Bunicii crește cu +40 % pe nivel
})
