--!strict
-- Peisajul satului de vale (Domain/VillageLayout, Config/Village):
-- - terenul: valea plană (iarba la y = −1, ca până acum), dealurile din nord și sud (Terrain), cu relief neregulat;
-- - pârâul și iazul, cu apă reală (Terrain Water);
-- - drumul mare, ulița de deal, ulicioarele și potecile, ca părți subțiri pe polilinii;
-- - podurile de lemn peste pârâu.
-- Gameplay-ul nu depinde de teren: ogrăzile, drumurile și locurile stau pe valea plană.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Village = require(Shared.Config.Village)
local VillageLayout = require(Shared.Domain.VillageLayout)
local Scatter = require(Shared.Domain.Scatter)

local VillageBuilder = {}

local GROUND_TOP = -1 -- fața ierbii (ogrăzile au solul lor la 0)
local CELL = 8

local PALETTE = {
	road = Color3.fromRGB(176, 146, 104),
	lane = Color3.fromRGB(160, 132, 94),
	path = Color3.fromRGB(140, 118, 84),
	plank = Color3.fromRGB(130, 88, 54),
}

-- Înălțimea dealurilor în afara văii (0 în vale), cu ondulații deterministe
function VillageBuilder.hillHeight(x: number, z: number): number
	local v = Village.valley
	local rise = 0
	if z > v.north then
		rise = (z - v.north) * v.hillSlope
	elseif z < v.south then
		rise = (v.south - z) * v.hillSlope
	end
	if rise <= 0 then
		return 0
	end
	local wave = 4 * math.sin(x / 47) + 3 * math.sin(x / 23 + z / 31) + 2 * math.sin(z / 19)
	return math.clamp(rise + wave * math.min(rise / 8, 1), 0, v.hillMax)
end

local function strip(
	name: string,
	a: Vector3,
	b: Vector3,
	width: number,
	color: Color3,
	material: Enum.Material,
	parent: Instance
)
	local flatA = Vector3.new(a.X, GROUND_TOP + 0.08, a.Z)
	local flatB = Vector3.new(b.X, GROUND_TOP + 0.08, b.Z)
	local length = (flatB - flatA).Magnitude
	if length < 0.1 then
		return
	end
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = material
	p.Color = color
	-- puțin mai lung decât segmentul: segmentele se suprapun la cotituri, fără goluri
	p.Size = Vector3.new(width, 0.16, length + width * 0.6)
	p.CFrame = CFrame.lookAt((flatA + flatB) / 2, flatB)
	p.Parent = parent
end

local function polyline(
	name: string,
	points: { Vector3 },
	width: number,
	color: Color3,
	material: Enum.Material,
	parent: Instance
)
	for i = 1, #points - 1 do
		strip(name, points[i], points[i + 1], width, color, material, parent)
	end
end

local function buildTerrain(layout: VillageLayout.Layout)
	local terrain = Workspace.Terrain
	local extentX = Village.extent + 360
	local north, south = Village.valley.north + 220, Village.valley.south - 160
	-- valea: o placă de iarbă cu fața la GROUND_TOP
	terrain:FillBlock(
		CFrame.new(0, GROUND_TOP - 4, (north + south) / 2),
		Vector3.new(extentX * 2, 8, north - south),
		Enum.Material.Grass
	)
	-- dealurile: bile suprapuse pe o grilă (relief rotunjit), doar în afara văii
	for x = -extentX, extentX, CELL do
		for z = south, north, CELL do
			local h = VillageBuilder.hillHeight(x, z)
			if h > 0.5 then
				terrain:FillBall(Vector3.new(x, GROUND_TOP + h - CELL, z), CELL * 1.25, Enum.Material.Grass)
			end
		end
	end
	-- pârâul: un șanț cu apă, de-a lungul drumului mare
	for i = 1, #layout.river - 1 do
		local a, b = layout.river[i], layout.river[i + 1]
		local mid = (a + b) / 2
		local length = (b - a).Magnitude + 4
		local cf = CFrame.lookAt(
			Vector3.new(mid.X, GROUND_TOP - 1.4, mid.Z),
			Vector3.new(b.X, GROUND_TOP - 1.4, b.Z)
		)
		terrain:FillBlock(cf, Vector3.new(Village.riverWidth + 4, 3.2, length), Enum.Material.Mud)
		terrain:FillBlock(cf, Vector3.new(Village.riverWidth, 3, length), Enum.Material.Air)
		terrain:FillBlock(
			cf * CFrame.new(0, -0.6, 0),
			Vector3.new(Village.riverWidth, 1.8, length),
			Enum.Material.Water
		)
	end
	-- iazul
	local pond = layout.sites.iaz.Position
	terrain:FillCylinder(CFrame.new(pond.X, GROUND_TOP - 1.2, pond.Z), 3, 36, Enum.Material.Mud)
	terrain:FillCylinder(CFrame.new(pond.X, GROUND_TOP - 0.8, pond.Z), 3.2, 32, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(pond.X, GROUND_TOP - 1.6, pond.Z), 1.6, 32, Enum.Material.Water)
end

local function buildBridges(layout: VillageLayout.Layout, parent: Instance)
	for i, cf in layout.bridges do
		local deck = Instance.new("Part")
		deck.Name = "Pod" .. i
		deck.Anchored = true
		deck.Material = Enum.Material.WoodPlanks
		deck.Color = PALETTE.plank
		deck.Size = Vector3.new(8, 0.6, Village.riverWidth + 8)
		deck.CFrame = CFrame.new(cf.Position.X, GROUND_TOP + 0.2, cf.Position.Z)
		deck.Parent = parent
		for _, side in { -1, 1 } do
			local rail = Instance.new("Part")
			rail.Name = "Balustrada"
			rail.Anchored = true
			rail.CanCollide = true
			rail.Material = Enum.Material.Wood
			rail.Color = PALETTE.plank
			rail.Size = Vector3.new(0.4, 1.2, Village.riverWidth + 8)
			rail.CFrame = deck.CFrame * CFrame.new(side * 3.8, 0.9, 0)
			rail.Parent = parent
		end
		-- poteca de la drumul mare la pod
		local road = VillageLayout.lower(Village.bridges[i])
		polyline("PotecaPod", { road, cf.Position }, 6, PALETTE.path, Enum.Material.Ground, parent)
	end
end

-- Decorul împrăștiat (Poisson): copaci și tufe în vale, nu pe drumuri, ogrăzi, locuri sau în pârâu.
-- Piese simple, fără coliziuni și fără umbre (bugetul de randare: Task 10).
local function free(layout: VillageLayout.Layout, p: Vector3, margin: number): boolean
	if VillageLayout.distanceToRoad(layout, p) < Village.roadWidth / 2 + margin then
		return false
	end
	for _, trail in layout.trails do
		for k = 1, #trail.points - 1 do
			local a, b = trail.points[k], trail.points[k + 1]
			local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			local t = math.clamp((Vector3.new(p.X - a.X, 0, p.Z - a.Z)):Dot(ab) / ab:Dot(ab), 0, 1)
			if (Vector3.new(p.X, 0, p.Z) - Vector3.new(a.X, 0, a.Z) - ab * t).Magnitude < 4 + margin then
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
		if (Vector3.new(site.X, 0, site.Z) - Vector3.new(p.X, 0, p.Z)).Magnitude < 34 + margin then
			return false
		end
	end
	return VillageLayout.distanceToRiver(layout, p) > Village.riverWidth / 2 + margin
		and (Vector3.new(p.X, 0, p.Z) - Vector3.new(layout.sites.iaz.X, 0, layout.sites.iaz.Z)).Magnitude
			> 44
end

local SOFT = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }

local function softPart(
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	for key, value in SOFT do
		(p :: any)[key] = value
	end
	p.Parent = parent
end

local function scatter(layout: VillageLayout.Layout, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Scatter"
	local area = {
		min = Vector2.new(-Village.extent - 40, Village.valley.south + 10),
		max = Vector2.new(Village.extent + 40, Village.valley.north - 10),
	}
	local rng = Scatter.rng(Village.variantSeed * 101)
	local trees = Scatter.poisson(area, 34, function(p: Vector2)
		return free(layout, Vector3.new(p.X, 0, p.Y), 6)
	end, rng)
	for i, p in trees do
		local h = 12 + (i * 7) % 9
		local base = CFrame.new(p.X, GROUND_TOP, p.Y)
		local leaf = if i % 3 == 0 then Color3.fromRGB(62, 118, 52) else Color3.fromRGB(84, 140, 60)
		softPart(
			"Trunchi",
			Enum.PartType.Cylinder,
			Vector3.new(h * 0.5, h * 0.09, h * 0.09),
			base * CFrame.new(0, h * 0.25, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(96, 70, 48),
			Enum.Material.Wood,
			folder
		)
		softPart(
			"Coroana",
			Enum.PartType.Ball,
			Vector3.new(h * 0.75, h * 0.6, h * 0.75),
			base * CFrame.new(0, h * 0.68, 0),
			leaf,
			Enum.Material.Grass,
			folder
		)
		if i % 2 == 0 then
			softPart(
				"Coroana",
				Enum.PartType.Ball,
				Vector3.new(h * 0.5, h * 0.45, h * 0.5),
				base * CFrame.new(h * 0.18, h * 0.88, -h * 0.1),
				leaf,
				Enum.Material.Grass,
				folder
			)
		end
	end
	local bushes = Scatter.poisson(area, 22, function(p: Vector2)
		return free(layout, Vector3.new(p.X, 0, p.Y), 3)
	end, rng)
	for i, p in bushes do
		local size = 3 + (i * 5) % 3
		softPart(
			"Tufa",
			Enum.PartType.Ball,
			Vector3.new(size * 1.4, size, size * 1.4),
			CFrame.new(p.X, GROUND_TOP + size * 0.3, p.Y),
			Color3.fromRGB(78 + (i % 4) * 6, 132, 58),
			Enum.Material.Grass,
			folder
		)
		if i % 3 == 0 then
			softPart(
				"Floare",
				Enum.PartType.Ball,
				Vector3.new(0.8, 0.8, 0.8),
				CFrame.new(p.X + 1.2, GROUND_TOP + size * 0.75, p.Y),
				if i % 2 == 0 then Color3.fromRGB(240, 220, 80) else Color3.fromRGB(230, 90, 120),
				Enum.Material.SmoothPlastic,
				folder
			)
		end
	end
	-- stâlpii de curent de-a lungul drumului mare, cu cuiburi de barză (berzele: AmbientLifeController)
	for k = -6, 6 do
		local x = k * 52
		local road = VillageLayout.lower(x)
		local pole = CFrame.new(road.X, GROUND_TOP, road.Z - (Village.roadWidth / 2 + 3))
		local p = Instance.new("Part")
		p.Name = "Stalp"
		p.Anchored = true
		p.Size = Vector3.new(0.8, 16, 0.8)
		p.CFrame = pole * CFrame.new(0, 8, 0)
		p.Color = Color3.fromRGB(150, 146, 140)
		p.Material = Enum.Material.Concrete
		p.Parent = folder
		if k % 3 == 0 then
			softPart(
				"Cuib",
				Enum.PartType.Cylinder,
				Vector3.new(1, 4, 4),
				pole * CFrame.new(0, 16.4, 0) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(120, 92, 60),
				Enum.Material.Grass,
				folder
			)
			p:SetAttribute("Stork", true)
		end
	end
	folder.Parent = parent
	return #trees, #bushes
end

-- Construiește peisajul; drumurile intră în `parent` (Folder-ul satului).
function VillageBuilder.build(layout: VillageLayout.Layout, parent: Instance)
	buildTerrain(layout)
	local roads = Instance.new("Folder")
	roads.Name = "Roads"
	for _, road in layout.roads do
		local main = road.name == "drumulMare"
		polyline(
			road.name,
			road.points,
			road.width,
			if main then PALETTE.road else PALETTE.lane,
			if main then Enum.Material.Sand else Enum.Material.Ground,
			roads
		)
	end
	for _, path in layout.shortcuts do
		polyline(path.name, path.points, path.width, PALETTE.path, Enum.Material.Ground, roads)
	end
	for _, trail in layout.trails do
		polyline(trail.name, trail.points, trail.width, PALETTE.path, Enum.Material.Ground, roads)
	end
	buildBridges(layout, roads)
	roads.Parent = parent
	scatter(layout, parent)
end

return VillageBuilder
