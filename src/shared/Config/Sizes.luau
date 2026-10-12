--!strict
-- Mărimea se decide la plantare. `weight` = pondere în tragerea la sorți.

export type Size = {
	id: string,
	multiplier: number,
	scale: number, -- scara vizuală a modelului
	weight: number,
	announce: boolean,
}

local list: { Size } = {
	{ id = "Small", multiplier = 0.8, scale = 0.8, weight = 25, announce = false },
	{ id = "Normal", multiplier = 1, scale = 1, weight = 60, announce = false },
	{ id = "Big", multiplier = 1.5, scale = 1.35, weight = 13, announce = false },
	{ id = "Huge", multiplier = 3, scale = 2, weight = 2, announce = true },
}

local byId: { [string]: Size } = {}
for _, size in list do
	byId[size.id] = table.freeze(size)
end

return table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
	default = "Normal",
})
