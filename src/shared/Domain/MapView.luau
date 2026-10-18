--!strict
-- Harta satului: proiecția de sus (X → dreapta, Z → jos, nordul sus) într-un dreptunghi de pixeli, cu
-- proporțiile păstrate și satul centrat; și drumul înapoi, de la atingere la locul din sat.

export type Bounds = { minX: number, maxX: number, minZ: number, maxZ: number }

local MapView = {}

-- Marginile unui set de puncte, cu o margine în jur
function MapView.boundsOf(points: { Vector3 }, pad: number): Bounds
	local b = { minX = math.huge, maxX = -math.huge, minZ = math.huge, maxZ = -math.huge }
	for _, p in points do
		b.minX = math.min(b.minX, p.X)
		b.maxX = math.max(b.maxX, p.X)
		b.minZ = math.min(b.minZ, p.Z)
		b.maxZ = math.max(b.maxZ, p.Z)
	end
	b.minX -= pad
	b.maxX += pad
	b.minZ -= pad
	b.maxZ += pad
	return b
end

local function fit(b: Bounds, size: Vector2): (number, Vector2)
	local scale = math.min(size.X / (b.maxX - b.minX), size.Y / (b.maxZ - b.minZ))
	local used = Vector2.new((b.maxX - b.minX) * scale, (b.maxZ - b.minZ) * scale)
	return scale, (size - used) / 2
end

function MapView.toMap(b: Bounds, size: Vector2, p: Vector3): Vector2
	local scale, offset = fit(b, size)
	return offset + Vector2.new((p.X - b.minX) * scale, (p.Z - b.minZ) * scale)
end

function MapView.toWorld(b: Bounds, size: Vector2, uv: Vector2): Vector3
	local scale, offset = fit(b, size)
	local q = (uv - offset) / scale
	return Vector3.new(b.minX + q.X, 0, b.minZ + q.Y)
end

-- Câți pixeli înseamnă un stud
function MapView.scale(b: Bounds, size: Vector2): number
	return (fit(b, size))
end

return MapView
