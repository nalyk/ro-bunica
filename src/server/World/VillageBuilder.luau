--!strict
-- Peisajul satului de vale (Domain/VillageLayout, Config/Village):
-- - terenul: valea plană (iarba la y = −1, ca până acum), dealurile din nord și sud (Terrain), cu relief neregulat;
-- - pârâul și iazul, cu apă reală (Terrain Water);
-- - drumul mare, ulița de deal, ulicioarele și potecile, ca părți subțiri pe polilinii;
-- - podurile de lemn peste pârâu.
-- Gameplay-ul nu depinde de teren: ogrăzile, drumurile și locurile stau pe valea plană.

local MaterialService = game:GetService("MaterialService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Village = require(Shared.Config.Village)
local VillageLayout = require(Shared.Domain.VillageLayout)
local ArtLibrary = require(Shared.Visual.ArtLibrary)
local Vegetation = require(Shared.Domain.Vegetation)

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
	-- și la capetele de est și vest: valea e închisă de dealuri pe toate laturile (nu se vede marginea lumii)
	local edge = Village.extent + 60
	if math.abs(x) > edge then
		rise = math.max(rise, (math.abs(x) - edge) * v.hillSlope)
	end
	if rise <= 0 then
		return 0
	end
	local wave = 4 * math.sin(x / 47) + 3 * math.sin(x / 23 + z / 31) + 2 * math.sin(z / 19)
	return math.clamp(rise + wave * math.min(rise / 8, 1), 0, v.hillMax)
end

-- Unde e solul la (x, z): terenul (dealurile, malurile), fără apă; în vale, fața ierbii
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.IgnoreWater = true
local function groundAt(x: number, z: number): number
	groundParams.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), groundParams)
	return if hit then hit.Position.Y else GROUND_TOP
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
	-- pe suprafața terenului netezit (iarba iese peste fața plăcii cu până la 2 studs); peste albia
	-- pârâului rămâne la nivelul văii, sub poduri
	local function surface(x: number, z: number): number
		return math.max(groundAt(x, z), GROUND_TOP) + 0.1
	end
	-- nimic peste apă (iazul, pârâul): acolo sunt podurile și pontonul
	local waterParams = RaycastParams.new()
	waterParams.FilterType = Enum.RaycastFilterType.Include
	waterParams.FilterDescendantsInstances = { Workspace.Terrain }
	for _, q in { a, (a + b) / 2, b } do
		local hit = Workspace:Raycast(Vector3.new(q.X, 300, q.Z), Vector3.new(0, -600, 0), waterParams)
		if hit and hit.Material == Enum.Material.Water then
			return
		end
	end
	local ya, yb = surface(a.X, a.Z), surface(b.X, b.Z)
	local lift = math.max(0, surface((a.X + b.X) / 2, (a.Z + b.Z) / 2) - (ya + yb) / 2)
	local flatA = Vector3.new(a.X, ya + lift, a.Z)
	local flatB = Vector3.new(b.X, yb + lift, b.Z)
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

-- Pământul bătătorit de sub drumuri: doar materialul ierbii se schimbă (ReplaceMaterial nu mișcă
-- suprafața), în pătrate de voxeli de-a lungul drumului; marginile se topesc în iarbă
local function paintRoad(
	layout: VillageLayout.Layout,
	points: { Vector3 },
	width: number,
	material: Enum.Material
)
	local terrain = Workspace.Terrain
	local half = math.max(4, math.floor(width / 2 / 4 + 0.5) * 4)
	local done: { [string]: boolean } = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local steps = math.max(1, math.ceil((b - a).Magnitude / 4))
		for k = 0, steps do
			local p = a:Lerp(b, k / steps)
			local gx, gz = math.floor(p.X / 4 + 0.5) * 4, math.floor(p.Z / 4 + 0.5) * 4
			local id = gx .. ":" .. gz
			if
				not done[id]
				and VillageLayout.distanceToRiver(layout, p) > Village.riverWidth / 2 + width / 2 + 2
			then
				done[id] = true
				local region = Region3.new(
					Vector3.new(gx - half, GROUND_TOP - 8, gz - half),
					Vector3.new(gx + half, GROUND_TOP + 12, gz + half)
				):ExpandToGrid(4)
				terrain:ReplaceMaterial(region, 4, Enum.Material.Grass, material)
			end
		end
	end
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

-- Texturile satului peste materialele terenului (MaterialService „Sat…”, din tools/terrain_tex.py)
local TERRAIN_VARIANTS: { { material: Enum.Material, variant: string } } = {
	{ material = Enum.Material.Grass, variant = "SatIarba" },
	{ material = Enum.Material.Ground, variant = "SatPamant" },
	{ material = Enum.Material.Mud, variant = "SatNoroi" },
}
local function applyTerrainVariants()
	for _, pair in TERRAIN_VARIANTS do
		if MaterialService:FindFirstChild(pair.variant) then
			pcall(MaterialService.SetBaseMaterialOverride, MaterialService, pair.material, pair.variant)
		end
	end
end

local function buildTerrain(layout: VillageLayout.Layout)
	applyTerrainVariants()
	local terrain = Workspace.Terrain
	-- departe în toate direcțiile: dealurile închid orizontul (nici de sus nu se vede marginea lumii)
	local extentX = Village.extent + 700
	local north, south = Village.valley.north + 520, Village.valley.south - 460
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
				-- aproape de sat celule fine; departe, celule duble (mai puține umpleri, același contur)
				local far = math.abs(x) > Village.extent + 200
					or z > Village.valley.north + 160
					or z < Village.valley.south - 160
				if not far then
					terrain:FillBall(
						Vector3.new(x, GROUND_TOP + h - CELL, z),
						CELL * 1.25,
						Enum.Material.Grass
					)
				elseif (x // CELL) % 2 == 0 and (z // CELL) % 2 == 0 then
					terrain:FillBall(
						Vector3.new(x, GROUND_TOP + h - 2 * CELL, z),
						CELL * 2.5,
						Enum.Material.Grass
					)
				end
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
		-- podul sculptat (doar la vedere): podeaua și balustradele de mai sus rămân, invizibile, pentru mers
		local art = ArtLibrary.get("world.Pod")
		if art then
			local _, size = art:GetBoundingBox()
			art:ScaleTo((Village.riverWidth + 8) / math.max(size.X, 1))
			art.Name = "PodSculptat"
			art:PivotTo(
				CFrame.new(cf.Position.X, GROUND_TOP - 0.6, cf.Position.Z) * CFrame.Angles(0, math.pi / 2, 0)
			)
			local box, scaled = art:GetBoundingBox()
			art:PivotTo(
				art:GetPivot()
					+ Vector3.new(
						cf.Position.X - box.X,
						GROUND_TOP - 0.6 - (box.Y - scaled.Y / 2),
						cf.Position.Z - box.Z
					)
			)
			for _, piece in art:GetDescendants() do
				if piece:IsA("BasePart") then
					piece.CanCollide = false
				end
			end
			art.Parent = parent
			for _, piece in parent:GetChildren() do
				if
					piece:IsA("BasePart")
					and (
						piece == deck
						or (piece.Name == "Balustrada" and (piece.Position - deck.Position).Magnitude < 6)
					)
				then
					piece.Transparency = 1
				end
			end
		end
		-- poteca de la drumul mare la pod
		local road = VillageLayout.lower(Village.bridges[i])
		polyline("PotecaPod", { road, cf.Position }, 6, PALETTE.path, Enum.Material.Ground, parent)
	end
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

-- Copacul procedural de rezervă (doar când modelul sculptat lipsește)
local function fallbackTree(i: number, base: CFrame, folder: Instance)
	local h = 12 + (i * 7) % 9
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
end

-- Pietrele de câmp: trei bolovani rotunjiți din piatră (modelul TRELLIS ieșea pătat de negru)
local function stones(i: number, base: CFrame, scale: number, folder: Instance)
	local group = Instance.new("Model")
	group.Name = "Pietre"
	local shades =
		{ Color3.fromRGB(150, 146, 136), Color3.fromRGB(128, 126, 118), Color3.fromRGB(166, 158, 140) }
	local layout = { { 0, 0, 2.4 }, { 1.9, 0.6, 1.6 }, { -1.2, 1.5, 1.2 } }
	for k, spec in layout do
		local d = spec[3] * scale
		softPart(
			"Piatra",
			Enum.PartType.Ball,
			Vector3.new(d * 1.25, d * 0.8, d),
			base
				* CFrame.new(spec[1] * scale, d * 0.22, spec[2] * scale)
				* CFrame.Angles(0, (i + k) * 1.7, 0.12 * k),
			shades[(i + k) % #shades + 1],
			Enum.Material.Slate,
			group
		)
	end
	group.Parent = folder
end

-- Vegetația (Domain/Vegetation): modelele sculptate, fără coliziuni; umbre doar de la copaci
local function scatter(layout: VillageLayout.Layout, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Scatter"
	-- terenul scris în acest cadru apare în raycast abia în cadrul următor
	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()
	local plan = Vegetation.plan(layout, Village.variantSeed)
	local trees, small = 0, 0
	for i, item in plan do
		local isTree = Vegetation.TREES[item.key] == true
		local y = groundAt(item.x, item.z)
		local base = CFrame.new(item.x, y, item.z) * CFrame.Angles(0, math.rad(item.yaw), 0)
		local art = ArtLibrary.get(item.key)
		if art then
			art.Name = string.match(item.key, "%.(.+)$") or item.key
			if item.scale ~= 1 then
				art:ScaleTo(item.scale)
			end
			art:PivotTo(base)
			local bounds, size = art:GetBoundingBox()
			-- baza puțin în pământ: pe pantă rădăcinile nu plutesc
			local sink = if isTree then 0.5 * item.scale else 0.15
			art:PivotTo(art:GetPivot() + Vector3.new(0, y - (bounds.Y - size.Y / 2) - sink, 0))
			for _, d in art:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
					d.CastShadow = isTree
				end
			end
			art.Parent = folder
		elseif isTree then
			fallbackTree(i, base, folder)
		elseif item.key == "world.Pietre" then
			stones(i, base, item.scale, folder)
		else
			continue
		end
		if isTree then
			trees += 1
		else
			small += 1
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
			-- stâlpul cu cuib se vede de oriunde (berzele de pe el sunt semnul satului)
			local nest = Instance.new("Model")
			nest.Name = "StalpBarza"
			nest.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
			p.Parent = nest
			softPart(
				"Cuib",
				Enum.PartType.Cylinder,
				Vector3.new(1, 4, 4),
				pole * CFrame.new(0, 16.4, 0) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(120, 92, 60),
				Enum.Material.Grass,
				nest
			)
			p:SetAttribute("Stork", true)
			-- stâlpul sculptat, cu cuibul și barza lui; stâlpul simplu rămâne invizibil (reperul berzei)
			local art = ArtLibrary.get("world.StalpBarza")
			if art then
				art.Name = "Sculptat"
				art:PivotTo(pole * CFrame.Angles(0, math.rad(k * 47), 0))
				local bounds, size = art:GetBoundingBox()
				art:PivotTo(art:GetPivot() + Vector3.new(0, pole.Y - (bounds.Y - size.Y / 2), 0))
				art.Parent = nest
				for _, piece in nest:GetChildren() do
					if piece:IsA("BasePart") then
						piece.Transparency = 1
					end
				end
				p:SetAttribute("Sculpted", true)
			end
			nest.Parent = folder
		end
	end
	folder.Parent = parent
	return trees, small
end

-- Construiește peisajul; drumurile intră în `parent` (Folder-ul satului).
function VillageBuilder.build(layout: VillageLayout.Layout, parent: Instance)
	buildTerrain(layout)
	local roads = Instance.new("Folder")
	roads.Name = "Roads"
	for _, road in layout.roads do
		paintRoad(
			layout,
			road.points,
			road.width,
			if road.name == "drumulMare" then Enum.Material.Ground else Enum.Material.Mud
		)
	end
	for _, path in layout.shortcuts do
		paintRoad(layout, path.points, path.width, Enum.Material.Mud)
	end
	for _, trail in layout.trails do
		paintRoad(layout, trail.points, trail.width, Enum.Material.Mud)
	end
	-- fâșiile se așază pe teren: terenul scris acum apare în raycast abia după un cadru
	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()
	for _, road in layout.roads do
		local main = road.name == "drumulMare"
		polyline(
			road.name,
			road.points,
			road.width,
			if main then PALETTE.road else PALETTE.lane,
			Enum.Material.Ground,
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
