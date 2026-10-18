--!strict
-- Decorul împrăștiat natural (eșantionare Poisson-disk, Bridson): puncte la cel puțin `radius` unul de altul,
-- doar unde masca permite (nu pe drumuri, nu în ogrăzi). Determinist pe seed.

export type Area = { min: Vector2, max: Vector2 }

local Scatter = {}

-- Generator determinist în [0, 1) (LCG; același rezultat în teste și în joc)
function Scatter.rng(seed: number): () -> number
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function(): number
		state = (state * 48271) % 2147483647
		return (state - 1) / 2147483646
	end
end

function Scatter.poisson(
	area: Area,
	radius: number,
	mask: (Vector2) -> boolean,
	rng: () -> number
): { Vector2 }
	local cell = radius / math.sqrt(2)
	local size = area.max - area.min
	local cols, rows = math.max(1, math.ceil(size.X / cell)), math.max(1, math.ceil(size.Y / cell))
	local grid: { [number]: Vector2 } = {}
	local points: { Vector2 } = {}
	local active: { Vector2 } = {}
	local function key(p: Vector2): (number, number)
		return math.floor((p.X - area.min.X) / cell), math.floor((p.Y - area.min.Y) / cell)
	end
	local function fits(p: Vector2): boolean
		if p.X < area.min.X or p.Y < area.min.Y or p.X > area.max.X or p.Y > area.max.Y or not mask(p) then
			return false
		end
		local gx, gy = key(p)
		for dx = -2, 2 do
			for dy = -2, 2 do
				local x, y = gx + dx, gy + dy
				if x >= 0 and y >= 0 and x < cols and y < rows then
					local other = grid[y * cols + x]
					if other and (other - p).Magnitude < radius then
						return false
					end
				end
			end
		end
		return true
	end
	local function add(p: Vector2)
		local gx, gy = key(p)
		grid[math.min(gy, rows - 1) * cols + math.min(gx, cols - 1)] = p
		table.insert(points, p)
		table.insert(active, p)
	end
	-- semințe: încercări aleatoare până la una permisă de mască
	for _ = 1, 60 do
		local p = area.min + Vector2.new(rng() * size.X, rng() * size.Y)
		if fits(p) then
			add(p)
		end
	end
	while #active > 0 do
		local index = math.floor(rng() * #active) + 1
		local origin = active[index]
		local found = false
		for _ = 1, 24 do
			local angle = rng() * math.pi * 2
			local distance = radius * (1 + rng())
			local p = origin + Vector2.new(math.cos(angle), math.sin(angle)) * distance
			if fits(p) then
				add(p)
				found = true
				break
			end
		end
		if not found then
			active[index] = active[#active]
			table.remove(active)
		end
	end
	return points
end

return Scatter
