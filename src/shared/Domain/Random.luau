--!strict
-- Utilitare de aleatoriu. `rng` întoarce un număr în [0, 1); se injectează pentru teste deterministe.

export type Rng = () -> number

local RandomUtil = {}

function RandomUtil.default(): Rng
	return math.random
end

-- Alege o cheie după ponderi. `entries` = listă de { value, weight }.
function RandomUtil.weighted<T>(entries: { { value: T, weight: number } }, rng: Rng): T?
	local total = 0
	for _, entry in entries do
		total += math.max(entry.weight, 0)
	end
	if total <= 0 then
		return nil
	end
	local roll = rng() * total
	for _, entry in entries do
		local weight = math.max(entry.weight, 0)
		if roll < weight then
			return entry.value
		end
		roll -= weight
	end
	return entries[#entries].value
end

-- Generator determinist (LCG) pentru teste și simulări.
function RandomUtil.seeded(seed: number): Rng
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function()
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
end

return RandomUtil
