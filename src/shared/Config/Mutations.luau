--!strict
-- Mutații. O creatură are cel mult una; `rank` mai mare o înlocuiește pe una mai mică.

export type Mutation = {
	id: string,
	rank: number,
	multiplier: number,
	color: Color3,
	announce: boolean,
}

local list: { Mutation } = {
	{ id = "Wet", rank = 1, multiplier = 2, color = Color3.fromRGB(80, 160, 255), announce = false },
	{ id = "Hail", rank = 2, multiplier = 3, color = Color3.fromRGB(200, 230, 255), announce = false },
	{ id = "Frozen", rank = 3, multiplier = 4, color = Color3.fromRGB(150, 230, 255), announce = true },
	{ id = "Golden", rank = 4, multiplier = 10, color = Color3.fromRGB(255, 205, 50), announce = true },
	-- Doar din „Supărarea Bunicii” (evenimentul de sâmbătă)
	{ id = "Papucita", rank = 5, multiplier = 15, color = Color3.fromRGB(200, 30, 40), announce = true },
	{ id = "Rainbow", rank = 6, multiplier = 20, color = Color3.fromRGB(255, 100, 200), announce = true },
}

local byId: { [string]: Mutation } = {}
for _, mutation in list do
	byId[mutation.id] = table.freeze(mutation)
end

return table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
})
