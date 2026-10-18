--!strict
-- Vegetația satului, pură și deterministă (docs/superpowers/plans/2026-10-18-grafica-satului.md, sarcina 4):
-- salcâmi de-a lungul drumului mare, pomi pe ulița de deal, plopi pe lângă calea ferată, livezi în spatele
-- ogrăzilor, pâlcuri de copaci cu tufe și flori prin câmpuri, codrul des pe dealuri, stuf pe malul iazului și al
-- pârâului, flori și pietre prin iarbă. Nimic pe drumuri, poteci, în ogrăzi, în locuri sau în apă.

local Config = script.Parent.Parent.Config
local Village = require(Config.Village)
local World = require(Config.World)
local VillageLayout = require(script.Parent.VillageLayout)
local Scatter = require(script.Parent.Scatter)

export type Placement = { key: string, x: number, z: number, yaw: number, scale: number }

local Vegetation = {}

-- Ce fel de lucru e fiecare cheie (pentru umbre și distanța de la drumuri)
Vegetation.TREES = {
	["world.Salcam"] = true,
	["world.Plop"] = true,
	["world.Nuc"] = true,
	["world.Stejar"] = true,
	["world.Mar"] = true,
	["world.Prun"] = true,
	["world.Visin"] = true,
	["world.Cires"] = true,
}
Vegetation.SMALL = {
	["world.Tufa"] = true,
	["world.Liliac"] = true,
	["world.Flori"] = true,
	["world.Stuf"] = true,
	["world.Pietre"] = true,
}

local SITE_CLEAR = 34 -- raza liberă din jurul unui loc (clădirile și jocurile lui)
local POND_WATER = 32 -- raza apei iazului (VillageBuilder)

local function flat(p: Vector3): Vector3
	return Vector3.new(p.X, 0, p.Z)
end

local function nearPolyline(p: Vector3, points: { Vector3 }, limit: number): boolean
	for k = 1, #points - 1 do
		local a, b = flat(points[k]), flat(points[k + 1])
		local ab = b - a
		local t = if ab.Magnitude < 1e-6 then 0 else math.clamp((flat(p) - a):Dot(ab) / ab:Dot(ab), 0, 1)
		if (flat(p) - (a + ab * t)).Magnitude < limit then
			return true
		end
	end
	return false
end

-- Locul e liber pentru ceva cu raza `margin`: departe de drumuri, poteci, ogrăzi, locuri, pârâu și iaz.
function Vegetation.free(layout: VillageLayout.Layout, p: Vector3, margin: number): boolean
	if VillageLayout.distanceToRoad(layout, p) < Village.roadWidth / 2 + margin then
		return false
	end
	for _, list in { layout.trails, layout.shortcuts } do
		for _, trail in list do
			if nearPolyline(p, trail.points, trail.width / 2 + 2 + margin) then
				return false
			end
		end
	end
	for _, plot in layout.plots do
		if VillageLayout.contains(plot, p, margin + 4) then
			return false
		end
	end
	for _, site in layout.sites do
		if (flat(site.Position) - flat(p)).Magnitude < SITE_CLEAR + margin then
			return false
		end
	end
	if math.abs(p.Z - Village.railwayZ) < 6 + margin then
		return false
	end
	if VillageLayout.distanceToRiver(layout, p) < Village.riverWidth / 2 + 1 + margin then
		return false
	end
	return (flat(layout.sites.iaz.Position) - flat(p)).Magnitude > POND_WATER + 4 + margin
end

-- Alege o cheie după ponderi, cu generatorul dat
local function pick(weights: { { any } }, rng: () -> number): string
	local total = 0
	for _, w in weights do
		total += w[2]
	end
	local r = rng() * total
	for _, w in weights do
		r -= w[2]
		if r <= 0 then
			return w[1]
		end
	end
	return weights[#weights][1]
end

-- Planul complet: o listă de așezări (cheie, x, z, rotire, scară), aceeași pentru același seed
function Vegetation.plan(layout: VillageLayout.Layout, seed: number): { Placement }
	local rng = Scatter.rng(seed * 7919 + 11)
	local out: { Placement } = {}
	local trunks: { Vector3 } = {} -- trunchiurile deja puse (copacii nu se suprapun)

	local function clearOfTrees(p: Vector3, distance: number): boolean
		for _, t in trunks do
			if (t - p).Magnitude < distance then
				return false
			end
		end
		return true
	end

	local function put(key: string, p: Vector3, scaleMin: number, scaleMax: number)
		if Vegetation.TREES[key] then
			table.insert(trunks, flat(p))
		end
		table.insert(out, {
			key = key,
			x = p.X,
			z = p.Z,
			yaw = rng() * 360,
			scale = scaleMin + (scaleMax - scaleMin) * rng(),
		})
	end

	local function tree(key: string, p: Vector3, margin: number, spacing: number, smin: number, smax: number)
		if Vegetation.free(layout, p, margin) and clearOfTrees(flat(p), spacing) then
			put(key, p, smin, smax)
			return true
		end
		return false
	end

	local extent = Village.extent
	local v = Village.valley

	-- 1. Salcâmii de pe marginile drumului mare (aleea satului), din 26 în 26, alternând părțile
	local side = 1
	for x = -extent, extent, 26 do
		local a, b = VillageLayout.lower(x - 1), VillageLayout.lower(x + 1)
		local along = flat(b - a).Unit
		local normal = Vector3.new(-along.Z, 0, along.X)
		local offset = Village.roadWidth / 2 + 6 + rng() * 2
		local p = VillageLayout.lower(x) + normal * offset * side + along * (rng() * 6 - 3)
		tree(if rng() < 0.85 then "world.Salcam" else "world.Nuc", p, 2, 12, 0.9, 1.15)
		side = -side
	end

	-- 2. Pomi rari pe ulița de deal (vișini, meri, pruni, cireși)
	for x = -extent, extent, 34 do
		local a, b = VillageLayout.upper(x - 1), VillageLayout.upper(x + 1)
		local along = flat(b - a).Unit
		local normal = Vector3.new(-along.Z, 0, along.X)
		local p = VillageLayout.upper(x)
			+ normal * (Village.laneWidth / 2 + 5) * (if rng() < 0.5 then 1 else -1)
		local key =
			pick({ { "world.Visin", 3 }, { "world.Mar", 2 }, { "world.Prun", 2 }, { "world.Cires", 2 } }, rng)
		tree(key, p, 2, 10, 0.85, 1.1)
	end

	-- 3. Plopii în șir, la nord de calea ferată (se văd de departe, ca în satele de câmpie)
	for x = -extent - 30, extent + 30, 15 do
		local p = Vector3.new(x + rng() * 3, 0, Village.railwayZ + 16 + rng() * 2)
		tree("world.Plop", p, 1, 9, 0.9, 1.15)
	end

	-- 4. Livezile din spatele ogrăzilor: câte 4–6 pomi pe două rânduri
	for _, plot in layout.plots do
		local back = plot.cframe * CFrame.new(0, 0, World.plotSize.Z / 2 + 14)
		for row = 0, 1 do
			for col = -1, 1 do
				if rng() < 0.85 then
					local p = (back * CFrame.new(col * 13 + rng() * 3, 0, row * 12 + rng() * 3)).Position
					local key = pick({
						{ "world.Mar", 3 },
						{ "world.Prun", 3 },
						{ "world.Visin", 2 },
						{ "world.Cires", 2 },
						{ "world.Nuc", 1 },
					}, rng)
					tree(key, p, 2, 9, 0.85, 1.05)
				end
			end
		end
	end

	-- 5. Pâlcurile din câmpuri: copaci strânși, cu tufe și flori la margine
	local valleyArea = {
		min = Vector2.new(-extent - 30, v.south + 12),
		max = Vector2.new(extent + 30, v.north - 8),
	}
	local centers = Scatter.poisson(valleyArea, 80, function(c: Vector2)
		return Vegetation.free(layout, Vector3.new(c.X, 0, c.Y), 12)
	end, rng)
	for _, c in centers do
		local center = Vector3.new(c.X, 0, c.Y)
		local count = 3 + math.floor(rng() * 4)
		for _ = 1, count * 3 do
			if count <= 0 then
				break
			end
			local angle, radius = rng() * math.pi * 2, 4 + rng() * 13
			local p = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			local key = pick({
				{ "world.Nuc", 3 },
				{ "world.Salcam", 3 },
				{ "world.Stejar", 1 },
				{ "world.Cires", 1 },
				{ "world.Prun", 1 },
			}, rng)
			if tree(key, p, 3, 8, 0.85, 1.2) then
				count -= 1
			end
		end
		for _ = 1, 2 + math.floor(rng() * 3) do
			local angle, radius = rng() * math.pi * 2, 16 + rng() * 6
			local p = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			if Vegetation.free(layout, p, 1.5) and clearOfTrees(flat(p), 5) then
				put(if rng() < 0.7 then "world.Tufa" else "world.Liliac", p, 0.85, 1.2)
			end
		end
		if rng() < 0.6 then
			local p = center + Vector3.new(rng() * 30 - 15, 0, 22 + rng() * 6)
			if Vegetation.free(layout, p, 1) and clearOfTrees(flat(p), 4) then
				put("world.Flori", p, 1, 1.5)
			end
		end
	end

	-- 6. Codrul pe dealuri: des lângă locul „codru”, o centură mai rară de-a lungul crestelor
	local codru = flat(layout.sites.codru.Position)
	local hillArea =
		{ min = Vector2.new(-extent - 60, v.north + 6), max = Vector2.new(extent + 60, v.north + 130) }
	for _, c in
		Scatter.poisson(hillArea, 15, function(q: Vector2)
			local p = Vector3.new(q.X, 0, q.Y)
			local near = (flat(p) - codru).Magnitude
			local density = if near < 45 then 0 elseif near < 120 then 0.85 else 0.12
			return Vegetation.free(layout, p, 4) and rng() < density
		end, rng)
	do
		local p = Vector3.new(c.X, 0, c.Y)
		local key = pick({ { "world.Stejar", 3 }, { "world.Nuc", 2 }, { "world.Salcam", 1 } }, rng)
		tree(key, p, 4, 9, 0.9, 1.3)
	end
	-- dealurile de sud (dincolo de calea ferată): pâlcuri rare de stejari
	local southArea =
		{ min = Vector2.new(-extent - 60, v.south - 150), max = Vector2.new(extent + 60, v.south - 25) }
	for _, c in
		Scatter.poisson(southArea, 16, function(q: Vector2)
			return Vegetation.free(layout, Vector3.new(q.X, 0, q.Y), 4) and rng() < 0.09
		end, rng)
	do
		tree(if rng() < 0.6 then "world.Stejar" else "world.Nuc", Vector3.new(c.X, 0, c.Y), 4, 9, 0.9, 1.3)
	end

	-- 7. Stuful: pe malul iazului (în arce, cu loc liber spre ponton) și pe malul pârâului
	local pond = flat(layout.sites.iaz.Position)
	for k = 0, 23 do
		local angle = k / 24 * math.pi * 2
		if math.abs(math.sin(angle)) > 0.35 or math.cos(angle) < 0 then -- spre nord-est rămâne ieșirea la apă
			local r = POND_WATER + 1 + rng() * 2.5
			put("world.Stuf", pond + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r), 0.85, 1.25)
		end
	end
	for k = 1, #layout.river - 1 do
		local a, b = layout.river[k], layout.river[k + 1]
		if rng() < 0.55 then
			local along = flat(b - a)
			if along.Magnitude > 1 then
				local normal = Vector3.new(-along.Unit.Z, 0, along.Unit.X) * (if rng() < 0.5 then 1 else -1)
				local p = (a + b) / 2 + normal * (Village.riverWidth / 2 + 1.5)
				if
					VillageLayout.distanceToRoad(layout, p) > Village.roadWidth / 2 + 4
					and not nearPolyline(p, layout.trails[1] and layout.trails[1].points or {}, 6)
				then
					put("world.Stuf", Vector3.new(p.X, 0, p.Z), 0.8, 1.2)
				end
			end
		end
	end

	-- 8. Flori și pietre prin iarbă; tufe pe lângă gardurile ogrăzilor
	for _, c in
		Scatter.poisson(valleyArea, 34, function(q: Vector2)
			return Vegetation.free(layout, Vector3.new(q.X, 0, q.Y), 2)
		end, rng)
	do
		local p = Vector3.new(c.X, 0, c.Y)
		if clearOfTrees(p, 5) then
			local r = rng()
			if r < 0.45 then
				put("world.Flori", p, 0.9, 1.4)
			elseif r < 0.6 then
				put("world.Pietre", p, 0.8, 1.3)
			end
		end
	end
	for _, plot in layout.plots do
		for _, sx in { -1, 1 } do
			for k = -2, 2 do
				if rng() < 0.45 then
					local local_ = CFrame.new(sx * (World.plotSize.X / 2 + 7), 0, k * World.plotSize.Z / 5)
					local p = (plot.cframe * local_).Position
					if Vegetation.free(layout, p, 1) and clearOfTrees(flat(p), 5) then
						put(if rng() < 0.6 then "world.Tufa" else "world.Liliac", p, 0.8, 1.1)
					end
				end
			end
		end
	end

	return out
end

-- Câte bucăți din fiecare cheie (pentru teste și jurnal)
function Vegetation.count(plan: { Placement }): { [string]: number }
	local counts: { [string]: number } = {}
	for _, item in plan do
		counts[item.key] = (counts[item.key] or 0) + 1
	end
	return counts
end

return Vegetation
