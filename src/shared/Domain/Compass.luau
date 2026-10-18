--!strict
-- Busola-bandă din HUD: unghiurile (nordul e −Z, estul +X, în grade 0–360), poziția semnelor pe bandă,
-- rândurile care le țin despărțite și distanța citită dintr-o privire.

local Compass = {}

Compass.STUD_METRES = 0.28

local CARDINALS = {
	{ id = "N", angle = 0 },
	{ id = "NE", angle = 45 },
	{ id = "E", angle = 90 },
	{ id = "SE", angle = 135 },
	{ id = "S", angle = 180 },
	{ id = "SV", angle = 225 },
	{ id = "V", angle = 270 },
	{ id = "NV", angle = 315 },
}

local function angleOf(dx: number, dz: number): number
	return math.deg(math.atan2(dx, -dz)) % 360
end

-- Încotro privește camera (vectorul de privire), în grade
function Compass.heading(look: Vector3): number
	return angleOf(look.X, look.Z)
end

-- Încotro e `to` văzut din `from`
function Compass.bearing(from: Vector3, to: Vector3): number
	return angleOf(to.X - from.X, to.Z - from.Z)
end

-- Unghiul de la `heading` la `bearing`, în (−180, 180]
function Compass.delta(bearing: number, heading: number): number
	local d = (bearing - heading) % 360
	return if d > 180 then d - 360 else d
end

-- Poziția pe bandă (0 = centrul) pentru un semn la `delta` grade, cu câmpul ±halfFov pe lățimea `width`.
-- În afara câmpului: nil, sau lipit de margine dacă semnul e fixat (ograda, ținta). Al doilea rezultat:
-- dacă stă pe margine.
function Compass.place(delta: number, halfFov: number, width: number, pinned: boolean?): (number?, boolean)
	local half = width / 2
	if math.abs(delta) <= halfFov then
		return delta / halfFov * half, false
	end
	if pinned then
		return if delta < 0 then -half else half, true
	end
	return nil, false
end

-- Punctele cardinale din câmp: { id, delta }
function Compass.cardinals(heading: number, halfFov: number): { { id: string, delta: number } }
	local list = {}
	for _, mark in CARDINALS do
		local d = Compass.delta(mark.angle, heading)
		if math.abs(d) <= halfFov then
			table.insert(list, { id = mark.id, delta = d })
		end
	end
	return list
end

-- Rândul fiecărui semn (0 = sus): în ordinea importanței (priority mic = important), primul rând în care
-- nu se apropie de altul la mai puțin de `gap` pixeli
function Compass.rows(
	markers: { { id: string, x: number, priority: number } },
	gap: number
): { [string]: number }
	local order = table.clone(markers)
	table.sort(order, function(a, b)
		return a.priority < b.priority
	end)
	local placed: { { x: number, row: number } } = {}
	local rows: { [string]: number } = {}
	for _, marker in order do
		local row = 0
		while true do
			local free = true
			for _, other in placed do
				if other.row == row and math.abs(other.x - marker.x) < gap then
					free = false
					break
				end
			end
			if free then
				break
			end
			row += 1
		end
		rows[marker.id] = row
		table.insert(placed, { x = marker.x, row = row })
	end
	return rows
end

-- Distanța în metri, rotunjită: din 5 în 5 sub 100 m, din 10 în 10 peste
function Compass.metres(studs: number): number
	local m = studs * Compass.STUD_METRES
	local step = if m < 100 then 5 else 10
	return math.floor(m / step + 0.5) * step
end

return Compass
