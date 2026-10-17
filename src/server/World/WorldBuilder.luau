--!strict
-- Generează satul din cod: teren, drum și ogrăzile de pe ambele părți ale drumului.
-- Coordonate locale ale unei ogrăzi: -Z = spre drum (față), +Z = spre casă (spate), X = lateral.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared.Config.World)
local VillageLayout = require(Shared.Domain.VillageLayout)
local VillageBuilder = require(script.Parent.VillageBuilder)
local Hora = require(Shared.Config.Hora)
local ArtLibrary = require(Shared.Visual.ArtLibrary)
local ArtFade = require(script.Parent.ArtFade)
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

-- Așezarea satului construit (după build); serviciile o citesc pentru locuri și drumuri.
WorldBuilder.layout = nil :: VillageLayout.Layout?

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

-- Pune un model din art/ (șablon din ArtLibrary) cu baza pe `cf` și fața spre cf.LookVector; nil dacă lipsește.
-- Modelele sunt doar vizuale (fără coliziuni); coliziunile rămân piesele invizibile din WorldBuilder.
local function placeArt(key: string, cf: CFrame, parent: Instance): Model?
	local model = ArtLibrary.get(key)
	if not model then
		return nil
	end
	model:PivotTo(cf)
	local box, size = model:GetBoundingBox()
	local offset = Vector3.new(
		cf.Position.X - box.Position.X,
		cf.Position.Y - (box.Position.Y - size.Y / 2),
		cf.Position.Z - box.Position.Z
	)
	model:PivotTo(model:GetPivot() + offset)
	model.Parent = parent
	return model
end

-- Ascunde piesele vechi (rămân coliziuni invizibile)
local function hide(parts: { BasePart })
	for _, p in parts do
		p.Transparency = 1
		for _, child in p:GetChildren() do
			if child:IsA("Decal") then
				child.Transparency = 1
			end
		end
	end
end

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

local function buildFence(model: Model, cf: CFrame, look: VillageLayout.Variant)
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
	local sculpted = ArtLibrary.has("world.GardLow")
	for _, segment in segments do
		local fence = part({
			Name = "Fence",
			Size = segment[2],
			CFrame = cf * CFrame.new(segment[1]),
			Color = PALETTE.fence,
			Material = Enum.Material.WoodPlanks,
			Parent = model,
		})
		if sculpted then
			-- gard de nuiele: segmente de 13 studs de-a lungul laturii, peste coliziunea invizibilă
			local alongX = segment[2].X > segment[2].Z
			local length = if alongX then segment[2].X else segment[2].Z
			local count = math.max(1, math.ceil(length / 12.6))
			for i = 1, count do
				local t = (i - 0.5) / count - 0.5
				local offset = if alongX then Vector3.new(t * length, 0, 0) else Vector3.new(0, 0, t * length)
				local base = cf * CFrame.new(segment[1].X + offset.X, 0, segment[1].Z + offset.Z)
				if not alongX then
					base *= CFrame.Angles(0, math.pi / 2, 0)
				end
				placeArt("world.GardLow", base, model)
			end
			hide({ fence })
		end
	end
	-- Stâlpii porții, vopsiți (cu poarta sculptată devin coliziuni invizibile)
	local gate = placeArt("world.Poarta", cf * CFrame.new(0, 0, -halfZ), model)
	for _, sideX in { -gateHalf, gateHalf } do
		local post = part({
			Name = "GatePost",
			Size = Vector3.new(1.5, h + 3, 1.5),
			CFrame = cf * CFrame.new(sideX, (h + 3) / 2, -halfZ),
			Color = look.gateColor,
			Parent = model,
		})
		if gate then
			hide({ post })
		end
	end
	-- vopseaua porții: textura are vopseaua transparentă (art.py, „paint”), deci se vede culoarea piesei
	if gate then
		for _, mesh in gate:GetDescendants() do
			if mesh:IsA("MeshPart") then
				mesh.Color = look.gateColor
			end
		end
	end
end

-- Decorul ogrăzii (doar vizual, fără coliziuni): patru seturi, oglindite stânga-dreapta pe jumătate din ogrăzi.
-- Straturile sunt la x ∈ [−34, −6], z ∈ [−18, −10]; piedestalele la x ∈ [4, 32], z ∈ [−21, 1]; decorul stă în spate
-- (z ≥ 2) sau pe fâșia din stânga, în fața straturilor.
local function decor(props: { [string]: any }): Part
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	return part(props)
end

local function buildPergola(model: Model, cf: CFrame, look: VillageLayout.Variant, side: number)
	-- bolta de viță pe latura din stânga, în spate (lângă casă): stâlpi, șipci, frunze
	for _, z in { 2, 10, 18, 26 } do
		for _, x in { -37.5, -32.5 } do
			decor({
				Name = "Bolta",
				Size = Vector3.new(0.5, 7, 0.5),
				CFrame = cf * CFrame.new(x * side, 3.5, z),
				Color = look.trimColor,
				Material = Enum.Material.Wood,
				Parent = model,
			})
		end
	end
	decor({
		Name = "BoltaSus",
		Size = Vector3.new(6, 0.4, 26),
		CFrame = cf * CFrame.new(-35 * side, 7.1, 14),
		Color = PALETTE.fence,
		Material = Enum.Material.WoodPlanks,
		Transparency = 0.35,
		Parent = model,
	})
	for i = 0, 6 do
		local leaf = decor({
			Name = "Vita",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4.4, 2.2, 4.4),
			CFrame = cf * CFrame.new((-35 + math.sin(i * 1.7) * 1.2) * side, 7.6, 2 + i * 4),
			Color = Color3.fromRGB(70 + i % 3 * 8, 128, 52),
			Material = Enum.Material.Grass,
			Parent = model,
		})
		leaf.Shape = Enum.PartType.Ball
		if i % 2 == 0 then
			decor({
				Name = "Strugure",
				Size = Vector3.new(0.8, 1.4, 0.8),
				CFrame = cf * CFrame.new((-34 + math.cos(i) * 1.5) * side, 6.1, 3 + i * 4),
				Color = Color3.fromRGB(88, 40, 96),
				Material = Enum.Material.SmoothPlastic,
				Parent = model,
			})
		end
	end
end

local function buildHives(model: Model, cf: CFrame, look: VillageLayout.Variant, side: number)
	-- stupii, vopsiți, în colțul din spate dreapta
	for i, z in { 6, 12, 18 } do
		decor({
			Name = "Stup",
			Size = Vector3.new(2.6, 2.4, 2.6),
			CFrame = cf * CFrame.new(34 * side, 1.6, z),
			Color = if i == 2 then look.trimColor else look.gateColor,
			Material = Enum.Material.WoodPlanks,
			Parent = model,
		})
		decor({
			Name = "StupCapac",
			Size = Vector3.new(3.0, 0.4, 3.0),
			CFrame = cf * CFrame.new(34 * side, 3.0, z),
			Color = PALETTE.roof,
			Parent = model,
		})
		decor({
			Name = "StupPicior",
			Size = Vector3.new(2.2, 0.4, 2.2),
			CFrame = cf * CFrame.new(34 * side, 0.2, z),
			Color = PALETTE.fence,
			Parent = model,
		})
	end
end

local function buildWoodpile(model: Model, cf: CFrame, side: number)
	-- stiva de lemne lângă gardul din spate și căpița de fân
	for row = 0, 2 do
		for i = 0, 6 - row do
			local log = decor({
				Name = "Lemn",
				Size = Vector3.new(4, 1, 1),
				CFrame = cf
					* CFrame.new((-26 + i * 1.05 + row * 0.5) * side, 0.5 + row * 0.95, 32)
					* CFrame.Angles(0, math.pi / 2, 0),
				Color = Color3.fromRGB(150 - row * 10, 104, 66),
				Material = Enum.Material.Wood,
				Parent = model,
			})
			log.Shape = Enum.PartType.Cylinder
		end
	end
	local hay = decor({
		Name = "Capita",
		Size = Vector3.new(7, 7, 7),
		CFrame = cf * CFrame.new(33 * side, 2.6, 26),
		Color = Color3.fromRGB(214, 180, 96),
		Material = Enum.Material.Grass,
		Parent = model,
	})
	hay.Shape = Enum.PartType.Ball
	decor({
		Name = "CapitaPar",
		Size = Vector3.new(0.4, 9, 0.4),
		CFrame = cf * CFrame.new(33 * side, 4.5, 26),
		Color = PALETTE.fence,
		Parent = model,
	})
end

local function buildDecor(model: Model, cf: CFrame, index: number, look: VillageLayout.Variant)
	local side = if look.mirrored then -1 else 1 -- oglindirea: decorul trece pe cealaltă latură
	local function at(x: number, z: number, turn: number): CFrame
		return cf * CFrame.new(x * side, 0, z) * CFrame.Angles(0, math.rad(turn), 0)
	end
	local set = look.treeSet
	if set == 1 then
		placeArt("world.Nuc", at(-30, 24, index * 47), model)
		placeArt("world.Nuc", at(31, 27, index * 83), model)
		placeArt("world.Visin", at(-33, 10, index * 61), model)
		placeArt("world.Visin", at(35, 9, index * 29), model)
		for k, zz in { -22, -9, 4 } do
			placeArt("world.FloareaSoarelui", at(-36.5, zz, k * 70), model)
		end
	elseif set == 2 then
		buildPergola(model, cf, look, side)
		placeArt("world.Nuc", at(31, 27, index * 83), model)
		placeArt("world.Visin", at(34, 8, index * 29), model)
	elseif set == 3 then
		buildHives(model, cf, look, side)
		placeArt("world.Visin", at(-33, 22, index * 61), model)
		placeArt("world.Visin", at(-31, 8, index * 37), model)
		for k, zz in { -22, -15, -8 } do
			placeArt("world.FloareaSoarelui", at(36.5, zz, k * 70), model)
		end
	else
		buildWoodpile(model, cf, side)
		placeArt("world.Nuc", at(-31, 20, index * 47), model)
		for k, zz in { -22, -9, 4 } do
			placeArt("world.FloareaSoarelui", at(-36.5, zz, k * 70), model)
		end
	end
end

local function buildHouse(model: Model, cf: CFrame)
	local z = World.plotSize.Z / 2 - 9
	local art = placeArt("world.Casa", cf * CFrame.new(0, 0, z), model)
	local walls = part({
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
	local porch = part({
		Name = "Porch",
		Size = Vector3.new(26, 1, 5),
		CFrame = cf * CFrame.new(0, 0.5, z - 8.5),
		Color = PALETTE.fence,
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	if art then
		-- casa sculptată: piesele vechi devin coliziuni invizibile, potrivite pe forma ei
		local _, size = art:GetBoundingBox()
		walls.Size = Vector3.new(size.X * 0.82, 12, size.Z * 0.55)
		walls.CFrame = cf * CFrame.new(0, 6, z + size.Z * 0.18)
		porch.Size = Vector3.new(size.X * 0.82, 1, 5)
		local hidden: { BasePart } = { walls, porch }
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") and (child.Name == "Roof" or child.Name == "Stitch") then
				child.CanCollide = false
				table.insert(hidden, child)
			end
		end
		hide(hidden)
	end
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

local function buildPlot(
	index: number,
	cf: CFrame,
	look: VillageLayout.Variant,
	parent: Instance
): PlotGeometry
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
	buildFence(model, cf, look)
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
		-- stratul sculptat (ramă de lemn, brazde); GardenService îl estompează când e blocat
		local art = placeArt("world.Strat", cf * CFrame.new(position), model)
		if art then
			hide({ bed })
			ArtFade.link(bed, art)
		end
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
		-- felia de buștean cu ștergar, cu fața la nivelul coliziunii (0,6): baza puțin sub pământ
		local art = placeArt(
			"world.PedestalLow",
			cf * CFrame.new(position + Vector3.new(0, -0.3, 0)) * CFrame.Angles(0, math.rad(i * 37), 0),
			model
		)
		if art then
			hide({ pedestal })
			ArtFade.link(pedestal, art) -- CreatureService estompează modelul la piedestalele blocate
		end
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
		-- raftul sculptat (cu ștergar), cu scândura la nivelul raftului vechi
		if placeArt("world.RaftLow", shelf.CFrame * CFrame.new(0, 0.3 - 2.0, 0), model) then
			hide({ shelf })
		end
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

	if placeArt("world.Beci", cf * CFrame.new(22, 0, World.plotSize.Z / 2 - 17), model) then
		hide({ deposit })
	end
	buildDecor(model, cf, index, look)

	-- Tăblița cu numele proprietarului, deasupra porții (deasupra acoperișului porții sculptate)
	local signPart = part({
		Name = "Sign",
		Size = Vector3.new(World.gateWidth + 2, 2.5, 0.5),
		CFrame = cf * CFrame.new(
			0,
			World.fenceHeight + (if ArtLibrary.has("world.Poarta") then 6.2 else 3.5),
			-World.plotSize.Z / 2
		),
		Color = PALETTE.houseWall,
		Parent = model,
	})
	-- tăblița sculptată: scândura cu chenar albastru; textul rămâne pe piesa veche (invizibilă), puțin în față
	if placeArt("world.Tabla", signPart.CFrame * CFrame.new(0, -1.3, 0), model) then
		signPart.CFrame *= CFrame.new(0, 0, -0.75)
		signPart.Transparency = 1
		signPart.CanCollide = false
	end
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
	if placeArt("world.Fantana", CFrame.new(center + Vector3.new(0, -0.7, 0)), hearth) then
		hide({ well })
		for _, child in hearth:GetChildren() do
			if child:IsA("BasePart") and (child.Name == "Stalp" or child.Name == "Acoperis") then
				child.CanCollide = false
				hide({ child })
			end
		end
	end
	hearth.Parent = parent
end

function WorldBuilder.build(): { PlotGeometry }
	local village = Instance.new("Folder")
	village.Name = "Village"

	-- satul de vale: terenul, pârâul, drumurile (Domain/VillageLayout, World/VillageBuilder)
	local layout = VillageLayout.build()
	WorldBuilder.layout = layout
	VillageBuilder.build(layout, village)
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
	for index, spot in layout.plots do
		table.insert(plots, buildPlot(index, spot.cframe, spot.look, village))
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
