--!strict
-- Raritățile creaturilor. `order` crește cu valoarea.

export type Rarity = {
	id: string,
	order: number,
	color: Color3,
	stealHoldSeconds: number, -- cât ține hoțul apăsat ca să ridice creatura
	carrySpeedMultiplier: number, -- viteza hoțului cât o cară
	announceHatch: boolean, -- eclozarea e anunțată pe server
	announceEverywhere: boolean?, -- și pe toate serverele (BroadcastService)
	announceSteal: boolean, -- furtul e anunțat pe server
	shopChance: number, -- șansa ca o sămânță de această raritate să apară în stoc la reînnoire
}

local list: { Rarity } = {
	{
		id = "Common",
		order = 1,
		color = Color3.fromRGB(190, 190, 190),
		stealHoldSeconds = 1.5,
		carrySpeedMultiplier = 0.75,
		announceHatch = false,
		announceSteal = false,
		shopChance = 1,
	},
	{
		id = "Rare",
		order = 2,
		color = Color3.fromRGB(70, 150, 255),
		stealHoldSeconds = 2,
		carrySpeedMultiplier = 0.75,
		announceHatch = false,
		announceSteal = false,
		shopChance = 0.6,
	},
	{
		id = "Epic",
		order = 3,
		color = Color3.fromRGB(170, 80, 230),
		stealHoldSeconds = 2.5,
		carrySpeedMultiplier = 0.7,
		announceHatch = false,
		announceSteal = true,
		shopChance = 0.3,
	},
	{
		id = "Legendary",
		order = 4,
		color = Color3.fromRGB(255, 180, 30),
		stealHoldSeconds = 3,
		carrySpeedMultiplier = 0.6,
		announceHatch = true,
		announceSteal = true,
		shopChance = 0.1,
	},
	{
		id = "Mythic",
		order = 5,
		color = Color3.fromRGB(230, 40, 60),
		stealHoldSeconds = 3.5,
		carrySpeedMultiplier = 0.6,
		announceHatch = true,
		announceEverywhere = true,
		announceSteal = true,
		shopChance = 0.03,
	},
	{
		id = "Secret",
		order = 6,
		color = Color3.fromRGB(20, 20, 20),
		stealHoldSeconds = 4,
		carrySpeedMultiplier = 0.55,
		announceHatch = true,
		announceEverywhere = true,
		announceSteal = true,
		shopChance = 0,
	},
}

local byId: { [string]: Rarity } = {}
for _, rarity in list do
	byId[rarity.id] = table.freeze(rarity)
end

return table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
})
