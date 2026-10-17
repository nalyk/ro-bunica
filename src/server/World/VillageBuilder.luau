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
	buildBridges(layout, roads)
	roads.Parent = parent
end

return VillageBuilder
