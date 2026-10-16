--!strict
-- Generează satul din cod: teren, drum și ogrăzile de pe ambele părți ale drumului.
-- Coordonate locale ale unei ogrăzi: -Z = spre drum (față), +Z = spre casă (spate), X = lateral.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared.Config.World)
local Hora = require(Shared.Config.Hora)
local Typography = require(Shared.Visual.Typography)

export type PlotGeometry = {
	index: number,
	cframe: CFrame, -- centrul ogrăzii, LookVector spre drum
	model: Model,
	beds: { [string]: BasePart },
	pedestals: { [string]: BasePart },
	showcase: { BasePart },
	deposit: BasePart,
	bunicaCFrame: CFrame,
	spawnCFrame: CFrame,
	spawn: SpawnLocation, -- RespawnLocation pentru proprietar
	sign: TextLabel,
	creatureFolder: Folder,
}

local WorldBuilder = {}

local PALETTE = {
	grass = Color3.fromRGB(110, 170, 70),
	road = Color3.fromRGB(170, 140, 100),
	yard = Color3.fromRGB(125, 180, 80),
	fence = Color3.fromRGB(150, 95, 55),
	gate = Color3.fromRGB(60, 110, 200), -- porți vopsite albastru, ca la sat
	houseWall = Color3.fromRGB(245, 240, 225),
	roof = Color3.fromRGB(180, 60, 45),
	soil = Color3.fromRGB(90, 60, 40),
	pedestal = Color3.fromRGB(235, 225, 200),
	stitch = Color3.fromRGB(200, 30, 40), -- roșul broderiei
	cellar = Color3.fromRGB(70, 45, 30),
}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function plotCFrame(index: number): CFrame
	local perSide = math.ceil(World.plotCount / 2)
	local side = if index <= perSide then 1 else -1
	local slot = if side == 1 then index else index - perSide
	local x = (slot - (perSide + 1) / 2) * (World.plotSize.X + World.plotGap)
	local z = side * (World.roadWidth / 2 + World.plotSize.Z / 2)
	local center = Vector3.new(x, 0, z)
	return CFrame.lookAt(center, Vector3.new(x, 0, 0))
end

local function buildFence(model: Model, cf: CFrame)
	local halfX, halfZ = World.plotSize.X / 2, World.plotSize.Z / 2
	local h = World.fenceHeight
	local gateHalf = World.gateWidth / 2
	local segments = {
		-- spate, stânga, dreapta
		{ Vector3.new(0, h / 2, halfZ), Vector3.new(World.plotSize.X, h, 1) },
		{ Vector3.new(-halfX, h / 2, 0), Vector3.new(1, h, World.plotSize.Z) },
		{ Vector3.new(halfX, h / 2, 0), Vector3.new(1, h, World.plotSize.Z) },
		-- fața, cu deschidere pentru poartă în mijloc
		{ Vector3.new(-(halfX + gateHalf) / 2, h / 2, -halfZ), Vector3.new(halfX - gateHalf, h, 1) },
		{ Vector3.new((halfX + gateHalf) / 2, h / 2, -halfZ), Vector3.new(halfX - gateHalf, h, 1) },
	}
	for _, segment in segments do
		part({
			Name = "Fence",
			Size = segment[2],
			CFrame = cf * CFrame.new(segment[1]),
			Color = PALETTE.fence,
			Material = Enum.Material.WoodPlanks,
			Parent = model,
		})
	end
	-- Stâlpii porții, vopsiți
	for _, sideX in { -gateHalf, gateHalf } do
		part({
			Name = "GatePost",
			Size = Vector3.new(1.5, h + 3, 1.5),
			CFrame = cf * CFrame.new(sideX, (h + 3) / 2, -halfZ),
			Color = PALETTE.gate,
			Parent = model,
		})
	end
end

local function buildHouse(model: Model, cf: CFrame)
	local z = World.plotSize.Z / 2 - 9
	part({
		Name = "HouseWalls",
		Size = Vector3.new(26, 12, 12),
		CFrame = cf * CFrame.new(0, 6, z),
		Color = PALETTE.houseWall,
		Parent = model,
	})
	local roof = Instance.new("WedgePart")
	roof.Anchored = true
	roof.Name = "Roof"
	roof.Size = Vector3.new(28, 6, 7)
	roof.Color = PALETTE.roof
	roof.CFrame = cf * CFrame.new(0, 15, z - 3.5) * CFrame.Angles(0, math.pi, 0)
	roof.Parent = model
	local roofBack = roof:Clone()
	roofBack.CFrame = cf * CFrame.new(0, 15, z + 3.5)
	roofBack.Parent = model
	-- Brâu brodat sub streașină
	part({
		Name = "Stitch",
		Size = Vector3.new(26.2, 0.6, 12.2),
		CFrame = cf * CFrame.new(0, 11, z),
		Color = PALETTE.stitch,
		Parent = model,
	})
	-- Prispa
	part({
		Name = "Porch",
		Size = Vector3.new(26, 1, 5),
		CFrame = cf * CFrame.new(0, 0.5, z - 8.5),
		Color = PALETTE.fence,
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
end

local function gridPositions(columns: number, rows: number, spacing: number, origin: Vector3): { Vector3 }
	local list = {}
	for row = 1, rows do
		for column = 1, columns do
			local x = origin.X + (column - (columns + 1) / 2) * spacing
			local z = origin.Z + (row - (rows + 1) / 2) * spacing
			table.insert(list, Vector3.new(x, origin.Y, z))
		end
	end
	return list
end

local function buildPlot(index: number, parent: Instance): PlotGeometry
	local cf = plotCFrame(index)
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("PlotIndex", index)

	part({
		Name = "Ground",
		Size = World.plotSize,
		CFrame = cf * CFrame.new(0, -0.5, 0),
		Color = PALETTE.yard,
		Material = Enum.Material.Grass,
		Parent = model,
	})
	buildFence(model, cf)
	buildHouse(model, cf)

	local beds: { [string]: BasePart } = {}
	local bedGrid = World.bedGrid
	for i, position in gridPositions(bedGrid.columns, bedGrid.rows, bedGrid.spacing, Vector3.new(-20, 0, -14)) do
		local bed = part({
			Name = "Bed" .. i,
			Size = Vector3.new(5, 0.8, 5),
			CFrame = cf * CFrame.new(position + Vector3.new(0, 0.4, 0)),
			Color = PALETTE.soil,
			Material = Enum.Material.Ground,
			Parent = model,
		})
		bed:SetAttribute("BedKey", tostring(i))
		beds[tostring(i)] = bed
	end

	local pedestals: { [string]: BasePart } = {}
	local pedGrid = World.pedestalGrid
	for i, position in gridPositions(pedGrid.columns, pedGrid.rows, pedGrid.spacing, Vector3.new(18, 0, -10)) do
		local pedestal = part({
			Name = "Pedestal" .. i,
			Shape = Enum.PartType.Cylinder,
			-- Joase (0,6), ca jucătorii să pășească peste ele fără să se agațe în grilă
			Size = Vector3.new(0.6, 5, 5),
			CFrame = cf * CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = PALETTE.pedestal,
			Parent = model,
		})
		pedestal:SetAttribute("PedestalKey", tostring(i))
		pedestals[tostring(i)] = pedestal
	end

	local showcase: { BasePart } = {}
	for i = 1, World.showcaseSlots do
		local shelf = part({
			Name = "Showcase" .. i,
			Size = Vector3.new(4, 0.6, 3),
			CFrame = cf * CFrame.new(-30 + (i - 1) * 6, World.fenceHeight + 0.3, -World.plotSize.Z / 2),
			Color = PALETTE.stitch,
			Parent = model,
		})
		table.insert(showcase, shelf)
	end

	local deposit = part({
		Name = "CellarDoor",
		Size = Vector3.new(6, 0.6, 5),
		CFrame = cf * CFrame.new(22, 0.3, World.plotSize.Z / 2 - 17) * CFrame.Angles(math.rad(-12), 0, 0),
		Color = PALETTE.cellar,
		Material = Enum.Material.Wood,
		CanCollide = false,
		Parent = model,
	})

	-- Tăblița cu numele proprietarului, deasupra porții
	local signPart = part({
		Name = "Sign",
		Size = Vector3.new(World.gateWidth + 2, 2.5, 0.5),
		CFrame = cf * CFrame.new(0, World.fenceHeight + 3.5, -World.plotSize.Z / 2),
		Color = PALETTE.houseWall,
		Parent = model,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.PixelsPerStud = 40
	surface.Parent = signPart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.FontFace = Typography.display
	label.TextColor3 = PALETTE.stitch
	label.Text = ""
	label.Parent = surface

	-- Locul de reînviere al proprietarului (invizibil; setat ca Player.RespawnLocation)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "OwnerSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Enabled = false -- doar prin RespawnLocation, nu pentru spawn-uri aleatorii
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = cf * CFrame.new(0, 0.5, 0)
	spawn.Parent = model

	local creatureFolder = Instance.new("Folder")
	creatureFolder.Name = "Creatures"
	creatureFolder.Parent = model

	model.Parent = parent
	return {
		index = index,
		cframe = cf,
		model = model,
		beds = beds,
		pedestals = pedestals,
		showcase = showcase,
		deposit = deposit,
		bunicaCFrame = cf * CFrame.new(0, 1, World.plotSize.Z / 2 - 17) * CFrame.Angles(0, math.pi, 0),
		-- Mijlocul ogrăzii, cu fața spre drum: camera nu intră în Bunica de pe prispă
		spawnCFrame = cf * CFrame.new(0, 3, 0),
		spawn = spawn,
		sign = label,
		creatureFolder = creatureFolder,
	}
end

-- Vatra satului: cercul brodat pentru Horă, cu fântâna în mijloc
local function buildHearth(parent: Instance)
	local hearth = Instance.new("Model")
	hearth.Name = "Vatra"
	local center = Hora.center
	local ring = Instance.new("Part")
	ring.Name = "HoraRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.12, Hora.radius * 2, Hora.radius * 2)
	ring.CFrame = CFrame.new(center + Vector3.new(0, -0.77, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Color = PALETTE.stitch
	ring.Material = Enum.Material.Fabric
	ring.Parent = hearth
	local inner = ring:Clone()
	inner.Name = "HoraFloor"
	inner.Size = Vector3.new(0.14, Hora.radius * 2 - 1.6, Hora.radius * 2 - 1.6)
	inner.Color = PALETTE.houseWall
	inner.Parent = hearth
	-- Fântâna: ghizd de piatră, doi stâlpi și acoperiș
	local well = Instance.new("Part")
	well.Name = "Fantana"
	well.Anchored = true
	well.Shape = Enum.PartType.Cylinder
	well.Size = Vector3.new(3, Hora.wellRadius * 2, Hora.wellRadius * 2)
	well.CFrame = CFrame.new(center + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	well.Color = Color3.fromRGB(150, 150, 150)
	well.Material = Enum.Material.Cobblestone
	well.Parent = hearth
	for _, side in { -1, 1 } do
		part({
			Name = "Stalp",
			Size = Vector3.new(0.6, 6, 0.6),
			CFrame = CFrame.new(center + Vector3.new(side * Hora.wellRadius, 3, 0)),
			Color = PALETTE.fence,
			Material = Enum.Material.Wood,
			Parent = hearth,
		})
	end
	part({
		Name = "Acoperis",
		Size = Vector3.new(Hora.wellRadius * 2 + 2, 0.6, 3.5),
		CFrame = CFrame.new(center + Vector3.new(0, 6.2, 0)),
		Color = PALETTE.gate,
		Parent = hearth,
	})
	hearth.Parent = parent
end

function WorldBuilder.build(): { PlotGeometry }
	local village = Instance.new("Folder")
	village.Name = "Village"

	local length = (World.plotSize.X + World.plotGap) * math.ceil(World.plotCount / 2) + 200
	part({
		Name = "Grass",
		Size = Vector3.new(length, 2, World.plotSize.Z * 2 + World.roadWidth + 200),
		CFrame = CFrame.new(0, -2, 0),
		Color = PALETTE.grass,
		Material = Enum.Material.Grass,
		Parent = village,
	})
	part({
		Name = "Road",
		Size = Vector3.new(length, 0.2, World.roadWidth),
		CFrame = CFrame.new(0, -0.9, 0),
		Color = PALETTE.road,
		Material = Enum.Material.Sand,
		Parent = village,
	})
	buildHearth(village)

	-- Spawn-ul neutru (înainte de încărcarea profilului), pe drum, departe de fântână
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(Hora.center + Vector3.new(Hora.radius + 12, -0.5, 0))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Parent = village

	local plots = {}
	for index = 1, World.plotCount do
		table.insert(plots, buildPlot(index, village))
	end
	village.Parent = Workspace

	Lighting.ClockTime = 17
	Lighting.Brightness = 2
	return plots
end

-- Este poziția în interiorul ogrăzii?
function WorldBuilder.contains(geometry: PlotGeometry, position: Vector3): boolean
	local localPos = geometry.cframe:PointToObjectSpace(position)
	return math.abs(localPos.X) <= World.plotSize.X / 2
		and math.abs(localPos.Z) <= World.plotSize.Z / 2
		and localPos.Y > -10
		and localPos.Y < 60
end

return WorldBuilder
