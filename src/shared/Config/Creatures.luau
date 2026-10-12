--!strict
-- Creaturile. Aspectul procedural (`look`) e placeholder până apare `modelId`.
-- `seedPrice = nil` înseamnă că sămânța nu se vinde (doar din evenimente).

export type LookPart = {
	shape: "Ball" | "Block" | "Cylinder" | "Wedge",
	size: Vector3,
	offset: Vector3, -- față de centrul corpului
	color: Color3,
}

export type Look = {
	body: LookPart,
	parts: { LookPart },
}

export type Creature = {
	id: string,
	rarity: string,
	income: number, -- lei pe secundă, înainte de multiplicatori
	growSeconds: number,
	seedPrice: number?,
	modelId: number?,
	look: Look,
}

local function part(shape: any, size: Vector3, offset: Vector3, color: Color3): LookPart
	return { shape = shape, size = size, offset = offset, color = color }
end

local V = Vector3.new
local RGB = Color3.fromRGB
local ZERO = V(0, 0, 0)

local list: { Creature } = {
	{
		id = "CartofelAgent",
		rarity = "Common",
		income = 1,
		growSeconds = 20,
		seedPrice = 10,
		look = {
			body = part("Ball", V(2, 2.4, 2), ZERO, RGB(180, 140, 90)),
			parts = { part("Block", V(1.6, 0.35, 0.2), V(0, 0.4, -0.95), RGB(20, 20, 20)) }, -- ochelari
		},
	},
	{
		id = "ArdeiasIute",
		rarity = "Common",
		income = 3,
		growSeconds = 40,
		seedPrice = 50,
		look = {
			body = part("Cylinder", V(2.6, 1.4, 1.4), ZERO, RGB(220, 40, 30)),
			parts = { part("Cylinder", V(0.6, 0.3, 0.3), V(0, 1.5, 0), RGB(60, 150, 50)) },
		},
	},
	{
		id = "CovrigSkater",
		rarity = "Common",
		income = 5,
		growSeconds = 60,
		seedPrice = 100,
		look = {
			body = part("Cylinder", V(0.6, 2.4, 2.4), ZERO, RGB(190, 120, 50)),
			parts = { part("Block", V(2.4, 0.2, 0.9), V(0, -1.4, 0), RGB(60, 60, 200)) },
		},
	},
	{
		id = "GogoasaNinja",
		rarity = "Rare",
		income = 12,
		growSeconds = 120,
		seedPrice = 600,
		look = {
			body = part("Cylinder", V(1.2, 2.6, 2.6), ZERO, RGB(210, 150, 80)),
			parts = { part("Block", V(2.7, 0.4, 0.3), V(0, 0.3, -0.7), RGB(20, 20, 20)) },
		},
	},
	{
		id = "CeapaTurbo",
		rarity = "Rare",
		income = 18,
		growSeconds = 150,
		seedPrice = 1200,
		look = {
			body = part("Ball", V(2.4, 2.6, 2.4), ZERO, RGB(200, 160, 220)),
			parts = {
				part("Block", V(0.7, 0.6, 1), V(-0.6, -1.4, 0), RGB(60, 60, 60)),
				part("Block", V(0.7, 0.6, 1), V(0.6, -1.4, 0), RGB(60, 60, 60)),
			},
		},
	},
	{
		id = "StrugurelFurios",
		rarity = "Rare",
		income = 25,
		growSeconds = 180,
		seedPrice = 2000,
		look = {
			body = part("Ball", V(2.2, 2.8, 2.2), ZERO, RGB(110, 40, 140)),
			parts = { part("Cylinder", V(0.8, 0.25, 0.25), V(0, 1.6, 0), RGB(90, 60, 30)) },
		},
	},
	{
		id = "PepeneBoxer",
		rarity = "Epic",
		income = 60,
		growSeconds = 300,
		seedPrice = 6000,
		look = {
			body = part("Ball", V(3, 2.6, 2.6), ZERO, RGB(40, 140, 60)),
			parts = {
				part("Ball", V(0.9, 0.9, 0.9), V(-1.7, 0, -0.5), RGB(220, 30, 30)),
				part("Ball", V(0.9, 0.9, 0.9), V(1.7, 0, -0.5), RGB(220, 30, 30)),
			},
		},
	},
	{
		id = "SarmalinaBallerina",
		rarity = "Epic",
		income = 90,
		growSeconds = 330,
		seedPrice = 12000,
		look = {
			body = part("Cylinder", V(2.6, 1.6, 1.6), ZERO, RGB(120, 160, 70)),
			parts = { part("Cylinder", V(0.2, 2.6, 2.6), V(0, -0.9, 0), RGB(255, 170, 200)) }, -- tutu
		},
	},
	{
		id = "Mamaligator",
		rarity = "Epic",
		income = 120,
		growSeconds = 360,
		seedPrice = 20000,
		look = {
			body = part("Block", V(1.8, 1.4, 3.6), ZERO, RGB(240, 200, 60)),
			parts = { part("Wedge", V(1.6, 0.8, 1.6), V(0, -0.1, -2.5), RGB(230, 185, 50)) },
		},
	},
	{
		id = "BranzoiSumo",
		rarity = "Legendary",
		income = 300,
		growSeconds = 540,
		seedPrice = 100000,
		look = {
			body = part("Block", V(3, 3, 3), ZERO, RGB(250, 245, 225)),
			parts = { part("Block", V(3.1, 0.5, 3.1), V(0, -0.6, 0), RGB(200, 30, 30)) },
		},
	},
	{
		id = "PlacintonioBombardino",
		rarity = "Legendary",
		income = 500,
		growSeconds = 600,
		seedPrice = 200000,
		look = {
			body = part("Cylinder", V(0.9, 3.2, 3.2), ZERO, RGB(215, 160, 80)),
			parts = {
				part("Wedge", V(0.2, 0.8, 1.8), V(-2, 0, 0), RGB(240, 240, 240)),
				part("Wedge", V(0.2, 0.8, 1.8), V(2, 0, 0), RGB(240, 240, 240)),
			},
		},
	},
	{
		id = "ColtunasPirat",
		rarity = "Legendary",
		income = 700,
		growSeconds = 660,
		seedPrice = 300000,
		look = {
			body = part("Ball", V(2.8, 2, 2.2), ZERO, RGB(245, 235, 210)),
			parts = { part("Ball", V(0.5, 0.5, 0.2), V(0.5, 0.4, -1.05), RGB(20, 20, 20)) },
		},
	},
	{
		id = "CozonacRobot",
		rarity = "Mythic",
		income = 2000,
		growSeconds = 1080,
		seedPrice = 2000000,
		look = {
			body = part("Block", V(2.4, 3.4, 2.4), ZERO, RGB(180, 110, 50)),
			parts = { part("Cylinder", V(1, 0.15, 0.15), V(0, 2.2, 0), RGB(180, 180, 190)) },
		},
	},
	{
		id = "DovleacDJ",
		rarity = "Mythic",
		income = 5000,
		growSeconds = 1200,
		seedPrice = 5000000,
		look = {
			body = part("Ball", V(3.4, 2.8, 3.4), ZERO, RGB(245, 130, 20)),
			parts = { part("Block", V(3.6, 0.4, 0.4), V(0, 1.2, 0), RGB(30, 30, 30)) }, -- căști
		},
	},
	{
		id = "RetetaSecreta",
		rarity = "Secret",
		income = 25000,
		growSeconds = 1500,
		seedPrice = nil,
		look = {
			body = part("Block", V(2.6, 3.2, 0.8), ZERO, RGB(120, 20, 30)),
			parts = { part("Block", V(2.2, 2.8, 0.2), V(0, 0, -0.45), RGB(240, 230, 200)) },
		},
	},
}

local byId: { [string]: Creature } = {}
for _, creature in list do
	byId[creature.id] = table.freeze(creature)
end

return table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
	starterSeed = "CartofelAgent", -- sămânța deja plantată la prima intrare
})
