--!strict
-- Locurile satului (docs/RESEARCH_SAT_VIU.md §3): 17 repere construite procedural, fiecare un Model în
-- Workspace.Village.Sites, așezat pe teren și cu fața spre centru (−Z local). Modelul sculptat („site.<cheie>”)
-- îl înlocuiește dacă există în ArtLibrary. Reperele numite (Tarc, Culoar, Labirint, Peron…) sunt folosite de
-- întâmplări și mini-jocuri; textele au atributul TextKey (traduse pe client, SiteController).

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ArtLibrary = require(Shared.Visual.ArtLibrary)
local Maze = require(Shared.Domain.Maze)
local Village = require(Shared.Config.Village)
local Zones = require(script.Parent.Zones)

local SiteBuilder = {}

local C = {
	wall = Color3.fromRGB(242, 236, 222),
	blue = Color3.fromRGB(64, 112, 186),
	wood = Color3.fromRGB(128, 86, 52),
	darkWood = Color3.fromRGB(88, 60, 38),
	roof = Color3.fromRGB(172, 72, 48),
	tin = Color3.fromRGB(150, 156, 160),
	concrete = Color3.fromRGB(170, 168, 160),
	straw = Color3.fromRGB(214, 182, 100),
	leaf = Color3.fromRGB(70, 128, 54),
	darkLeaf = Color3.fromRGB(38, 82, 44),
	corn = Color3.fromRGB(150, 168, 66),
	gold = Color3.fromRGB(222, 178, 64),
	red = Color3.fromRGB(196, 44, 44),
	white = Color3.fromRGB(250, 250, 248),
	dirt = Color3.fromRGB(150, 118, 80),
}

-- Primitivele ------------------------------------------------------------------------------------------------

type Props = { [string]: any }

local function make(
	class: string,
	model: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	props: Props?
): BasePart
	local p = Instance.new(class) :: BasePart
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in (props or {}) :: Props do
		(p :: any)[key] = value
	end
	p.Parent = model
	return p
end

local function box(
	model: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	props: Props?
): BasePart
	return make("Part", model, name, size, cf, color, props)
end

-- Cilindru vertical (axa Roblox a cilindrului e X: îl rotim)
local function cyl(
	model: Instance,
	name: string,
	height: number,
	diameter: number,
	cf: CFrame,
	color: Color3,
	props: Props?
): BasePart
	local p = make(
		"Part",
		model,
		name,
		Vector3.new(height, diameter, diameter),
		cf * CFrame.Angles(0, 0, math.pi / 2),
		color,
		props
	) :: Part
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(
	model: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	props: Props?
): BasePart
	local p = make("Part", model, name, size, cf, color, props) :: Part
	p.Shape = Enum.PartType.Ball
	return p
end

local function wedge(
	model: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	props: Props?
): BasePart
	return make("WedgePart", model, name, size, cf, color, props)
end

-- Fără coliziuni (frunze, stuf, decor)
local SOFT: Props = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
local function soft(extra: Props?): Props
	local t = table.clone(SOFT)
	for k, v in (extra or {}) :: Props do
		t[k] = v
	end
	return t
end

-- Reper invizibil (pentru întâmplări și mini-jocuri)
local function marker(model: Instance, name: string, size: Vector3, cf: CFrame): BasePart
	return box(model, name, size, cf, C.white, soft({ Transparency = 1 }))
end

-- Acoperiș în două ape peste o cutie lată `w`, adâncă `d`, cu streașină
local function gable(model: Instance, cf: CFrame, w: number, d: number, h: number, color: Color3)
	wedge(
		model,
		"Acoperis",
		Vector3.new(w + 1.6, h, d / 2 + 0.8),
		cf * CFrame.new(0, h / 2, -(d / 4 + 0.4)),
		color,
		{ Material = Enum.Material.Slate }
	)
	wedge(
		model,
		"Acoperis",
		Vector3.new(w + 1.6, h, d / 2 + 0.8),
		cf * CFrame.new(0, h / 2, d / 4 + 0.4) * CFrame.Angles(0, math.pi, 0),
		color,
		{ Material = Enum.Material.Slate }
	)
end

-- O casă simplă: pereți, ușă spre față (−Z), două ferestre albastre, acoperiș
local function house(
	model: Instance,
	cf: CFrame,
	w: number,
	d: number,
	h: number,
	wallColor: Color3,
	roofColor: Color3
)
	box(
		model,
		"Perete",
		Vector3.new(w, h, d),
		cf * CFrame.new(0, h / 2, 0),
		wallColor,
		{ Material = Enum.Material.Plaster }
	)
	box(
		model,
		"Usa",
		Vector3.new(3, 6, 0.3),
		cf * CFrame.new(0, 3, -d / 2 - 0.1),
		C.darkWood,
		{ CanCollide = false }
	)
	for _, side in { -1, 1 } do
		box(
			model,
			"Fereastra",
			Vector3.new(2.6, 2.6, 0.3),
			cf * CFrame.new(side * w / 3.2, h * 0.58, -d / 2 - 0.1),
			C.blue,
			{ CanCollide = false, Material = Enum.Material.Glass }
		)
	end
	gable(model, cf * CFrame.new(0, h, 0), w, d, math.max(3, d * 0.42), roofColor)
end

-- Tăbliță cu text tradus pe client (TextKey)
local function sign(model: Instance, cf: CFrame, width: number, key: string, fallback: string)
	local board = box(model, "Tablita", Vector3.new(width, 2.2, 0.3), cf, C.white, { CanCollide = false })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = C.blue
	label.Text = fallback
	label:SetAttribute("TextKey", key)
	label.Parent = gui
end

local function tree(model: Instance, cf: CFrame, height: number, leafColor: Color3, fruit: Color3?)
	cyl(
		model,
		"Trunchi",
		height * 0.55,
		height * 0.09,
		cf * CFrame.new(0, height * 0.27, 0),
		C.darkWood,
		soft({ Material = Enum.Material.Wood })
	)
	ball(
		model,
		"Coroana",
		Vector3.new(height * 0.7, height * 0.55, height * 0.7),
		cf * CFrame.new(0, height * 0.72, 0),
		leafColor,
		soft({ Material = Enum.Material.Grass })
	)
	if fruit then
		for i = 1, 7 do
			local a = i * 2.4
			ball(
				model,
				"Fruct",
				Vector3.new(0.6, 0.6, 0.6),
				cf
					* CFrame.new(
						math.cos(a) * height * 0.3,
						height * (0.6 + (i % 3) * 0.08),
						math.sin(a) * height * 0.3
					),
				fruit,
				soft()
			)
		end
	end
end

-- Înălțimea terenului (raycast doar pe Terrain)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { Workspace.Terrain }

function SiteBuilder.groundY(x: number, z: number): number
	local hit = Workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), rayParams)
	return if hit then hit.Position.Y else -1
end

-- Pune `cf` (orizontal) pe teren
local function onGround(cf: CFrame): CFrame
	local p = cf.Position
	return cf + Vector3.new(0, SiteBuilder.groundY(p.X, p.Z) - p.Y, 0)
end

-- Pune un model sculptat cu baza (nu pivotul) pe `cf`, ca WorldBuilder.placeArt
local function placeOnBase(model: Model, cf: CFrame)
	model:PivotTo(cf)
	local bounds, size = model:GetBoundingBox()
	model:PivotTo(
		model:GetPivot() + Vector3.new(cf.X - bounds.X, cf.Y - (bounds.Y - size.Y / 2), cf.Z - bounds.Z)
	)
end

-- Modelul sculptat (TRELLIS, art/models.json), așezat cu baza pe `cf` și fața spre −Z; nil dacă nu există încă
local function sculpted(parent: Instance, key: string, cf: CFrame, name: string?, scale: number?): Model?
	local art = ArtLibrary.get(key)
	if not art then
		return nil
	end
	art.Name = name or string.match(key, "%.(.+)$") or key
	if scale and scale ~= 1 then
		art:ScaleTo(scale)
	end
	placeOnBase(art, cf)
	art.Parent = parent
	return art
end

-- Întinde un model sculptat pe axe (în spațiul pivotului): piesele importate au rotația pivotului
local function stretch(model: Model, scale: Vector3)
	local pivot = model:GetPivot()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local rel = pivot:ToObjectSpace(part.CFrame)
			part.Size *= scale
			part.CFrame = pivot * (CFrame.new(rel.Position * scale) * rel.Rotation)
		end
	end
end

-- Un obiect de context (lăiță, saci, căruță, lemne...) pus pe teren, fără coliziuni; nimic dacă lipsește modelul
local function prop(parent: Instance, key: string, cf: CFrame, scale: number?): Model?
	return sculpted(parent, key, onGround(cf), nil, scale)
end

-- Coliziunea invizibilă a unei clădiri sculptate (modelele de artă nu au coliziuni)
local function collider(model: Instance, name: string, size: Vector3, cf: CFrame)
	box(model, name, size, cf, C.white, { Transparency = 1, CastShadow = false, CanQuery = false })
end

local builders: { [string]: (Model, CFrame) -> () } = {}

-- Centrul: avizierul, băncile, țarcul de gâște, zona fără bătaie (fântâna și hora: WorldBuilder.buildHearth)
builders.centru = function(model, cf)
	local zone =
		cyl(model, "NoFightZone", 12, 64, cf * CFrame.new(0, 4, 0), C.white, soft({ Transparency = 1 }))
	Zones.markNoFight(zone)
	-- avizierul (recordurile de pe server apar aici)
	local board = cf * CFrame.new(-24, 0, 6) * CFrame.Angles(0, math.rad(90), 0)
	for _, side in { -1, 1 } do
		box(
			model,
			"AvizierStalp",
			Vector3.new(0.6, 7, 0.6),
			board * CFrame.new(side * 4.5, 3.5, 0),
			C.darkWood
		)
	end
	box(
		model,
		"Avizier",
		Vector3.new(8.4, 4.4, 0.4),
		board * CFrame.new(0, 4.6, 0),
		C.wood,
		{ Material = Enum.Material.WoodPlanks }
	)
	sign(model, board * CFrame.new(0, 7.6, -0.1), 8, "site.avizier", "AVIZIERUL SATULUI")
	wedge(model, "AvizierAcoperis", Vector3.new(9.4, 1, 1.6), board * CFrame.new(0, 8.4 + 0.7, 0), C.roof)
	-- al doilea avizier, alături: topul săptămânii din toate satele (LeaderboardService, atributul „TopWeek”)
	local top = board * CFrame.new(-10.5, 0, 0)
	for _, side in { -1, 1 } do
		box(model, "AvizierStalp", Vector3.new(0.6, 7, 0.6), top * CFrame.new(side * 4.5, 3.5, 0), C.darkWood)
	end
	box(
		model,
		"AvizierTop",
		Vector3.new(8.4, 4.4, 0.4),
		top * CFrame.new(0, 4.6, 0),
		C.wood,
		{ Material = Enum.Material.WoodPlanks }
	)
	sign(model, top * CFrame.new(0, 7.6, -0.1), 8, "site.topWeek", "TOPUL SĂPTĂMÂNII")
	wedge(model, "AvizierAcoperis", Vector3.new(9.4, 1, 1.6), top * CFrame.new(0, 8.4 + 0.7, 0), C.roof)
	-- băncile, la vest de horă (pe est trece rutiera)
	for _, at in
		{
			cf * CFrame.new(-16, 0, -16) * CFrame.Angles(0, math.rad(40), 0),
			cf * CFrame.new(-24, 0, -6) * CFrame.Angles(0, math.rad(70), 0),
		}
	do
		box(
			model,
			"Banca",
			Vector3.new(6, 0.4, 1.6),
			at * CFrame.new(0, 1.6, 0),
			C.wood,
			{ Material = Enum.Material.WoodPlanks }
		)
		box(
			model,
			"BancaSpatar",
			Vector3.new(6, 1.4, 0.3),
			at * CFrame.new(0, 2.5, 0.7),
			C.wood,
			{ Material = Enum.Material.WoodPlanks }
		)
		for _, side in { -1, 1 } do
			box(
				model,
				"BancaPicior",
				Vector3.new(0.4, 1.4, 1.4),
				at * CFrame.new(side * 2.6, 0.7, 0),
				C.darkWood
			)
		end
	end
	-- țarcul de gâște (Gâștele au scăpat: gâștele se aduc aici)
	local pen = cf * CFrame.new(36, 0, 4) -- la est de ocolul rutierei
	local penModel = Instance.new("Model")
	penModel.Name = "Tarc"
	penModel.Parent = model
	for _, s in { { 0, -5, 10, 0.4 }, { 0, 5, 10, 0.4 }, { -5, 0, 0.4, 10 }, { 5, 1.8, 0.4, 6.4 } } do
		box(
			penModel,
			"TarcGard",
			Vector3.new(s[3], 1.6, s[4]),
			pen * CFrame.new(s[1], 0.8, s[2]),
			C.wood,
			{ Material = Enum.Material.WoodPlanks }
		)
	end
	marker(penModel, "TarcZona", Vector3.new(9, 4, 9), pen * CFrame.new(0, 2, 0))
end

-- Magazinul satului: casă albă cu firmă, prispă, lăzi
builders.magazin = function(model, cf)
	if sculpted(model, "world.Magazin", cf) then
		marker(model, "Tejghea", Vector3.new(4, 4, 4), cf * CFrame.new(0, 2, -11))
		return
	end
	house(model, cf, 16, 11, 8, C.wall, C.tin)
	sign(model, cf * CFrame.new(0, 7, -5.7), 9, "site.magazin", "MAGAZIN")
	box(
		model,
		"Prispa",
		Vector3.new(16, 0.5, 4),
		cf * CFrame.new(0, 0.25, -7.5),
		C.concrete,
		{ Material = Enum.Material.Concrete }
	)
	for i = 0, 2 do
		box(
			model,
			"Lada",
			Vector3.new(2, 1.6, 2),
			cf * CFrame.new(5 + i * 0.4, 0.8 + i * 1.6, -8) * CFrame.Angles(0, math.rad(i * 17), 0),
			C.wood,
			{ Material = Enum.Material.WoodPlanks }
		)
	end
	box(
		model,
		"BancaMagazin",
		Vector3.new(5, 0.4, 1.4),
		cf * CFrame.new(-4.5, 1.5, -8.2),
		C.wood,
		{ Material = Enum.Material.WoodPlanks }
	)
	marker(model, "Tejghea", Vector3.new(4, 4, 4), cf * CFrame.new(0, 2, -9))
end

-- Stația de autobuz cu mozaic (ca cele sovietice, colorate)
builders.statie = function(model, cf)
	-- modelul stației are fața (banca, mozaicul) spre +Z: întors spre drum
	if sculpted(model, "world.Statie", cf * CFrame.Angles(0, math.pi, 0)) then
		marker(model, "Oprire", Vector3.new(6, 4, 6), cf * CFrame.new(0, 2, -5))
		return
	end
	box(
		model,
		"Placa",
		Vector3.new(12, 0.4, 5),
		cf * CFrame.new(0, 0.2, 0),
		C.concrete,
		{ Material = Enum.Material.Concrete }
	)
	box(
		model,
		"PereteSpate",
		Vector3.new(12, 6, 0.6),
		cf * CFrame.new(0, 3.4, 2.2),
		C.concrete,
		{ Material = Enum.Material.Concrete }
	)
	local palette =
		{ C.blue, C.gold, C.red, C.white, Color3.fromRGB(70, 150, 120), Color3.fromRGB(240, 140, 60) }
	for row = 0, 4 do
		for col = 0, 10 do
			local k = (row * 7 + col * 3 + (row * col) % 5) % #palette + 1
			box(
				model,
				"Mozaic",
				Vector3.new(1, 1, 0.1),
				cf * CFrame.new(-5 + col, 1.4 + row, 1.85),
				palette[k],
				soft({ Material = Enum.Material.Glass })
			)
		end
	end
	box(
		model,
		"AcoperisStatie",
		Vector3.new(13, 0.5, 6),
		cf * CFrame.new(0, 6.6, 0.4) * CFrame.Angles(math.rad(-6), 0, 0),
		C.concrete,
		{ Material = Enum.Material.Concrete }
	)
	for _, side in { -1, 1 } do
		box(
			model,
			"PereteLateral",
			Vector3.new(0.5, 6, 4.4),
			cf * CFrame.new(side * 5.8, 3.4, 0.2),
			C.concrete,
			{ Material = Enum.Material.Concrete }
		)
	end
	box(
		model,
		"BancaStatie",
		Vector3.new(9, 0.4, 1.4),
		cf * CFrame.new(0, 1.6, 1.2),
		C.wood,
		{ Material = Enum.Material.WoodPlanks }
	)
	sign(model, cf * CFrame.new(0, 7.6, -2.6), 6, "site.statie", "STAȚIA")
	marker(model, "Oprire", Vector3.new(6, 4, 6), cf * CFrame.new(0, 2, -5))
end

-- Casa de cultură (Discoteca): coloane, firmă, interior cu ring de dans luminat
builders.discoteca = function(model, cf)
	-- Casa de cultură sculptată în spate; ringul de dans în aer liber, în fața ei (vara, ca în sate), cu ghirlande
	-- de becuri și globul pe o arcadă. Jucătorii Discotecii stau pe ring (centrul locului).
	if sculpted(model, "world.CasaCultura", cf * CFrame.new(0, 0, 21), "CasaCultura", 1.25) then
		collider(model, "ZiduriCasa", Vector3.new(26, 16, 15), cf * CFrame.new(0, 8, 22))
		local colors = {
			Color3.fromRGB(255, 70, 160),
			Color3.fromRGB(70, 200, 255),
			Color3.fromRGB(255, 210, 60),
			Color3.fromRGB(120, 255, 120),
		}
		local floor = Instance.new("Model")
		floor.Name = "RingDans"
		floor.Parent = model
		box(
			floor,
			"Rama",
			Vector3.new(23, 0.4, 20),
			cf * CFrame.new(0, 0.2, 0),
			C.darkWood,
			{ Material = Enum.Material.WoodPlanks }
		)
		for x = -3, 3 do
			for z = -3, 2 do
				box(
					floor,
					"Placa",
					Vector3.new(2.9, 0.2, 2.9),
					cf * CFrame.new(x * 3, 0.45, z * 3 + 1.5),
					colors[(x + z) % 4 + 1],
					{ Material = Enum.Material.Neon }
				)
			end
		end
		-- stâlpii cu ghirlande de becuri, de jur împrejurul ringului
		local corners = {
			Vector3.new(-12, 0, -10),
			Vector3.new(12, 0, -10),
			Vector3.new(12, 0, 11),
			Vector3.new(-12, 0, 11),
		}
		for i, corner in corners do
			local base = cf * CFrame.new(corner)
			cyl(
				model,
				"StalpLumini",
				8,
				0.5,
				base * CFrame.new(0, 4, 0),
				C.darkWood,
				{ Material = Enum.Material.Wood }
			)
			local nextCorner = corners[i % #corners + 1]
			local a = (base * CFrame.new(0, 7.6, 0)).Position
			local b = (cf * CFrame.new(nextCorner) * CFrame.new(0, 7.6, 0)).Position
			for k = 1, 9 do
				local t = k / 10
				local sag = math.sin(t * math.pi) * 1.2
				ball(
					model,
					"Bec",
					Vector3.new(0.6, 0.6, 0.6),
					CFrame.new(a:Lerp(b, t) - Vector3.new(0, sag, 0)),
					colors[(i + k) % 4 + 1],
					soft({ Material = Enum.Material.Neon })
				)
			end
		end
		-- arcada cu globul de discotecă deasupra ringului
		for _, side in { -1, 1 } do
			cyl(
				model,
				"Arcada",
				9,
				0.6,
				cf * CFrame.new(side * 11, 4.5, 1),
				C.tin,
				{ Material = Enum.Material.Metal }
			)
		end
		box(
			model,
			"ArcadaSus",
			Vector3.new(22.6, 0.6, 0.6),
			cf * CFrame.new(0, 9, 1),
			C.tin,
			soft({ Material = Enum.Material.Metal })
		)
		local glob = ball(
			model,
			"Glob",
			Vector3.new(2.4, 2.4, 2.4),
			cf * CFrame.new(0, 7.4, 1),
			C.tin,
			soft({ Material = Enum.Material.Foil, Reflectance = 0.6 })
		)
		local light = Instance.new("PointLight")
		light.Range = 26
		light.Brightness = 2
		light.Color = Color3.fromRGB(255, 120, 220)
		light.Parent = glob
		prop(model, "world.Banca", cf * CFrame.new(-16, 0, -2) * CFrame.Angles(0, math.rad(90), 0))
		prop(model, "world.Banca", cf * CFrame.new(16, 0, -2) * CFrame.Angles(0, math.rad(-90), 0))
		prop(model, "world.Liliac", cf * CFrame.new(-16, 0, 14))
		prop(model, "world.Liliac", cf * CFrame.new(16, 0, 14))
		return
	end
	local w, d, h = 28, 20, 11
	box(
		model,
		"PereteSpate",
		Vector3.new(w, h, 1),
		cf * CFrame.new(0, h / 2, d / 2),
		C.wall,
		{ Material = Enum.Material.Plaster }
	)
	for _, side in { -1, 1 } do
		box(
			model,
			"PereteLateral",
			Vector3.new(1, h, d),
			cf * CFrame.new(side * w / 2, h / 2, 0),
			C.wall,
			{ Material = Enum.Material.Plaster }
		)
		-- fața, cu ușa largă în mijloc (6 studs)
		box(
			model,
			"PereteFata",
			Vector3.new(w / 2 - 3, h, 1),
			cf * CFrame.new(side * (w / 4 + 1.5), h / 2, -d / 2),
			C.wall,
			{ Material = Enum.Material.Plaster }
		)
	end
	box(
		model,
		"PesteUsa",
		Vector3.new(6, h - 7, 1),
		cf * CFrame.new(0, 7 + (h - 7) / 2, -d / 2),
		C.wall,
		{ Material = Enum.Material.Plaster }
	)
	box(
		model,
		"Tavan",
		Vector3.new(w + 1, 1, d + 1),
		cf * CFrame.new(0, h + 0.5, 0),
		C.concrete,
		{ Material = Enum.Material.Concrete }
	)
	box(
		model,
		"Fronton",
		Vector3.new(w + 3, 2.4, 1.2),
		cf * CFrame.new(0, h + 1.2, -d / 2 - 3.5),
		C.wall,
		{ Material = Enum.Material.Plaster }
	)
	for i = -2, 2 do
		cyl(
			model,
			"Coloana",
			h,
			1.4,
			cf * CFrame.new(i * 5.5, h / 2, -d / 2 - 3.5),
			C.white,
			{ Material = Enum.Material.Marble }
		)
	end
	box(
		model,
		"Treapta",
		Vector3.new(w, 0.6, 5),
		cf * CFrame.new(0, 0.3, -d / 2 - 3.2),
		C.concrete,
		{ Material = Enum.Material.Concrete }
	)
	sign(model, cf * CFrame.new(0, h + 1.2, -d / 2 - 4.15), 16, "site.discoteca", "CASA DE CULTURĂ")
	-- ringul de dans: plăci colorate, luminate de jos
	local floor = Instance.new("Model")
	floor.Name = "RingDans"
	floor.Parent = model
	local colors = {
		Color3.fromRGB(255, 70, 160),
		Color3.fromRGB(70, 200, 255),
		Color3.fromRGB(255, 210, 60),
		Color3.fromRGB(120, 255, 120),
	}
	for x = -3, 3 do
		for z = -2, 3 do
			box(
				floor,
				"Placa",
				Vector3.new(2.9, 0.2, 2.9),
				cf * CFrame.new(x * 3, 0.15, z * 3),
				colors[(x + z) % 4 + 1],
				{ Material = Enum.Material.Neon }
			)
		end
	end
	ball(
		model,
		"Glob",
		Vector3.new(2.4, 2.4, 2.4),
		cf * CFrame.new(0, h - 2, 1),
		C.tin,
		soft({ Material = Enum.Material.Foil, Reflectance = 0.6 })
	)
	box(
		model,
		"Scena",
		Vector3.new(12, 1.2, 4),
		cf * CFrame.new(0, 0.6, d / 2 - 2.6),
		C.darkWood,
		{ Material = Enum.Material.WoodPlanks }
	)
	local light = Instance.new("PointLight")
	light.Range = 22
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 120, 220)
	light.Parent = model:FindFirstChild("Glob")
end

-- Terenul școlii: teren de oina (60×28) cu linii, culoarul de alergare, porțile; școala alături
builders.terenScoala = function(model, cf)
	box(
		model,
		"Teren",
		Vector3.new(60, 0.3, 28),
		cf * CFrame.new(0, 0.15, 4),
		C.dirt,
		{ Material = Enum.Material.Ground }
	)
	for _, z in { -10, 18 } do
		box(model, "Linie", Vector3.new(60, 0.05, 0.4), cf * CFrame.new(0, 0.33, z), C.white, soft())
	end
	for _, x in { -30, 0, 30 } do
		box(model, "Linie", Vector3.new(0.4, 0.05, 28), cf * CFrame.new(x, 0.33, 4), C.white, soft())
	end
	for _, side in { -1, 1 } do
		local goal = cf * CFrame.new(side * 32, 0, 4)
		for _, z in { -3, 3 } do
			box(model, "Poarta", Vector3.new(0.5, 5, 0.5), goal * CFrame.new(0, 2.5, z), C.white)
		end
		box(model, "PoartaSus", Vector3.new(0.5, 0.5, 6.5), goal * CFrame.new(0, 5, 0), C.white)
	end
	-- culoarul oinei: de la linia de bătaie la capăt și înapoi (Task 19)
	local lane = marker(model, "Culoar", Vector3.new(56, 4, 4), cf * CFrame.new(0, 2, 15))
	lane:SetAttribute("Start", Vector3.new(-27, 0, 15))
	lane:SetAttribute("End", Vector3.new(27, 0, 15))
	marker(model, "Bataie", Vector3.new(6, 4, 6), cf * CFrame.new(-27, 2, 15))
	-- școala sculptată, cu fața spre teren; bănci de-a lungul terenului
	if
		sculpted(model, "world.Scoala", cf * CFrame.new(0, 0, -27) * CFrame.Angles(0, math.pi, 0), "Scoala")
	then
		collider(model, "ZiduriScoala", Vector3.new(30, 12, 12), cf * CFrame.new(0, 6, -27))
		for _, x in { -18, 0, 18 } do
			prop(model, "world.Banca", cf * CFrame.new(x, 0, 21) * CFrame.Angles(0, math.pi, 0))
		end
		prop(model, "world.Liliac", cf * CFrame.new(-19, 0, -15))
		prop(model, "world.Liliac", cf * CFrame.new(19, 0, -15))
		prop(model, "world.Flori", cf * CFrame.new(-10, 0, -16))
		prop(model, "world.Flori", cf * CFrame.new(10, 0, -16))
		return
	end
	house(
		model,
		cf * CFrame.new(0, 0, -22) * CFrame.Angles(0, math.pi, 0),
		24,
		10,
		8,
		Color3.fromRGB(246, 226, 170),
		C.tin
	)
	sign(model, cf * CFrame.new(0, 7.4, -16.8), 8, "site.scoala", "ȘCOALA")
end

-- Iazul: stuf pe mal, debarcaderul de lemn, o barcă (apa e în teren, VillageBuilder)
builders.iaz = function(model, cf)
	local reeds = ArtLibrary.has("world.Stuf") -- stuful sculptat e pus de vegetație (Domain/Vegetation)
	for i = 1, if reeds then 0 else 36 do
		local a = i * 0.5236 + (i % 3) * 0.2
		local r = 30 + (i % 4) * 1.6
		local base = cf * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r)
		if math.cos(a) > -0.35 or math.sin(a) < 0.5 then -- golul de la debarcader rămâne liber
			for k = 0, 2 do
				cyl(
					model,
					"Stuf",
					5 + k,
					0.25,
					base * CFrame.new(k * 0.6 - 0.6, (5 + k) / 2, (k % 2) * 0.5),
					Color3.fromRGB(110, 140, 60),
					soft()
				)
			end
		end
	end
	local pier = Instance.new("Model")
	pier.Name = "Debarcader"
	pier.Parent = model
	local start = cf * CFrame.new(0, 0, 34) * CFrame.Angles(0, math.pi, 0)
	box(
		pier,
		"Scanduri",
		Vector3.new(4, 0.4, 18),
		start * CFrame.new(0, 0.5, 9),
		C.wood,
		{ Material = Enum.Material.WoodPlanks }
	)
	for z = 1, 17, 4 do
		for _, side in { -1, 1 } do
			cyl(
				pier,
				"Par",
				3,
				0.5,
				start * CFrame.new(side * 1.8, -0.8, z),
				C.darkWood,
				{ Material = Enum.Material.Wood }
			)
		end
	end
	marker(pier, "Capat", Vector3.new(4, 4, 4), start * CFrame.new(0, 2, 17))
	-- pontonul sculptat peste scândurile pe care se merge (rămân, invizibile, pentru pescuit)
	local ponton = ArtLibrary.get("world.Ponton")
	if ponton then
		ponton.Name = "Ponton"
		local size = ponton:GetExtentsSize()
		ponton:ScaleTo(18 / math.max(size.X, size.Z))
		ponton:PivotTo(
			start * CFrame.new(0, 0, 9) * CFrame.Angles(0, if size.X > size.Z then math.pi / 2 else 0, 0)
		)
		local bounds, extent = ponton:GetBoundingBox()
		ponton:PivotTo(ponton:GetPivot() + Vector3.new(0, 0.7 - (bounds.Y + extent.Y / 2), 0))
		ponton.Parent = pier
		for _, child in pier:GetChildren() do
			if child:IsA("BasePart") and child.Name ~= "Capat" then
				child.Transparency = 1
			end
		end
		prop(model, "world.Banca", cf * CFrame.new(-6, 0, 40) * CFrame.Angles(0, math.pi, 0))
		prop(model, "world.Flori", cf * CFrame.new(8, 0, 41))
		return
	end
	local boat = start * CFrame.new(4.5, 0.1, 13)
	box(model, "Barca", Vector3.new(2.6, 1, 7), boat, C.wood, soft({ Material = Enum.Material.WoodPlanks }))
	wedge(
		model,
		"BarcaProra",
		Vector3.new(2.6, 1, 2),
		boat * CFrame.new(0, 0, -4.5) * CFrame.Angles(0, math.pi, 0),
		C.wood,
		soft()
	)
end

-- Livada: 5 cireși (sculptați dacă există) și căsuța mătușii Mărioara
builders.livada = function(model, cf)
	for i, at in { { -14, -6 }, { 0, -10 }, { 14, -6 }, { -8, 8 }, { 9, 9 } } do
		local place = cf * CFrame.new(at[1], 0, at[2]) * CFrame.Angles(0, math.rad(i * 71), 0)
		local art = ArtLibrary.get("world.Cires") or ArtLibrary.get("world.Visin")
		if art then
			art.Name = "Cires"
			placeOnBase(art, onGround(place))
			art.Parent = model
		else
			tree(model, onGround(place), 11, C.leaf, C.red)
		end
		marker(model, "Cires" .. i, Vector3.new(6, 6, 6), place * CFrame.new(0, 3, 0))
	end
	house(model, cf * CFrame.new(0, 0, 22) * CFrame.Angles(0, math.pi, 0), 9, 7, 6, C.wall, C.roof)
	marker(model, "Matusa", Vector3.new(3, 5, 3), cf * CFrame.new(0, 2.5, 16))
	for x = -20, 20, 4 do
		box(
			model,
			"GardLivada",
			Vector3.new(0.4, 2, 0.4),
			cf * CFrame.new(x, 1, -18),
			C.wood,
			{ Material = Enum.Material.Wood }
		)
	end
	box(
		model,
		"GardLivadaSipca",
		Vector3.new(40, 0.3, 0.2),
		cf * CFrame.new(0, 1.6, -18),
		C.wood,
		{ Material = Enum.Material.Wood }
	)
end

-- Lanul de porumb: labirint 9×9 (Domain/Maze, seed fix), celule de 8 studs, pereți de porumb de 7 studs
builders.lanPorumb = function(model, cf)
	local CELL, N = 8, 9
	local maze = Maze.generate(N, N, 1918)
	local walls = Instance.new("Model")
	walls.Name = "Labirint"
	walls.Parent = model
	local origin = cf * CFrame.new(-N * CELL / 2, 0, -N * CELL / 2)
	local corn = ArtLibrary.has("world.Porumb")
	local function wall(a: Vector3, b: Vector3)
		local mid = (a + b) / 2
		local length = (b - a).Magnitude + 1.4
		local alongX = math.abs(b.X - a.X) > 0.1
		local block = box(
			walls,
			"Porumb",
			if alongX then Vector3.new(length, 7, 1.4) else Vector3.new(1.4, 7, length),
			origin * CFrame.new(mid.X, 3.5, mid.Z),
			C.corn,
			{ Material = Enum.Material.Grass }
		)
		if corn then
			-- zidul rămâne coliziunea (invizibilă); peste el, segmentul de lan sculptat
			block.Transparency = 1
			local turn = if alongX then 0 else math.pi / 2
			local flip = if (mid.X * 7 + mid.Z * 3) % 2 < 1 then 0 else math.pi
			local art = sculpted(
				walls,
				"world.Porumb",
				origin * CFrame.new(mid.X, 0, mid.Z) * CFrame.Angles(0, turn + flip, 0),
				"Lan"
			)
			if art then
				-- petecul de lan e aproape pătrat: lung cât zidul, subțiat la grosimea lui (coridoarele rămân libere)
				local size = art:GetExtentsSize()
				art:PivotTo(CFrame.new(art:GetPivot().Position))
				stretch(art, Vector3.new(length / size.X, 1, 2.6 / size.Z))
				placeOnBase(art, origin * CFrame.new(mid.X, 0, mid.Z) * CFrame.Angles(0, turn + flip, 0))
			end
		end
	end
	for y = 1, N do
		for x = 1, N do
			local x0, z0 = (x - 1) * CELL, (y - 1) * CELL
			if not Maze.open(maze, x, y, "E") and not (x == N and y == N) then
				wall(Vector3.new(x0 + CELL, 0, z0), Vector3.new(x0 + CELL, 0, z0 + CELL))
			end
			if not Maze.open(maze, x, y, "S") then
				wall(Vector3.new(x0, 0, z0 + CELL), Vector3.new(x0 + CELL, 0, z0 + CELL))
			end
			if x == 1 then
				wall(Vector3.new(0, 0, z0), Vector3.new(0, 0, z0 + CELL))
			end
			if y == 1 and x ~= 1 then -- intrarea: colțul (1,1), spre centrul satului
				wall(Vector3.new(x0, 0, 0), Vector3.new(x0 + CELL, 0, 0))
			end
		end
	end
	-- moțurile porumbului (doar la zidurile simple)
	for i = 1, if corn then 0 else 40 do
		local x, z = (i * 37) % (N * CELL), (i * 53) % (N * CELL)
		cyl(walls, "Mot", 1.2, 0.3, origin * CFrame.new(x, 7.6, z), C.gold, soft())
	end
	-- pătulul lângă intrare și sperietoarea în colțul de la ieșire (în afara labirintului)
	sculpted(
		model,
		"world.Patul",
		onGround(origin * CFrame.new(-7, 0, 6) * CFrame.Angles(0, math.rad(-90), 0)),
		"Patul"
	)
	sculpted(model, "world.Sperietoare", onGround(origin * CFrame.new(N * CELL + 5, 0, -4)), "Sperietoare")
	marker(model, "Intrare", Vector3.new(6, 4, 6), origin * CFrame.new(CELL / 2, 2, -3))
	marker(model, "Mijloc", Vector3.new(6, 4, 6), cf * CFrame.new(0, 2, 0))
	marker(model, "Iesire", Vector3.new(6, 4, 6), origin * CFrame.new(N * CELL + 3, 2, N * CELL - CELL / 2))
end

-- Via pe deal: 6 rânduri de araci cu sârmă și frunze, fiecare pe teren
builders.via = function(model, cf)
	for row = 0, 5 do
		local rowModel = Instance.new("Model")
		rowModel.Name = "Rand" .. (row + 1)
		rowModel.Parent = model
		local previous: Vector3? = nil
		for k = 0, 8 do
			local post = onGround(cf * CFrame.new(-20 + k * 5, 0, -15 + row * 6))
			cyl(
				rowModel,
				"Arac",
				4.4,
				0.35,
				post * CFrame.new(0, 2.2, 0),
				C.darkWood,
				{ Material = Enum.Material.Wood }
			)
			-- butucul sculptat la fiecare arac (frunzișul simplu doar dacă lipsește modelul)
			local vine = sculpted(
				rowModel,
				"world.ButucVie",
				post * CFrame.new(2.5, 0, 0) * CFrame.Angles(0, math.rad((row * 9 + k) * 37), 0),
				"Butuc"
			)
			if not vine then
				ball(
					rowModel,
					"Vita",
					Vector3.new(3.6, 2.2, 1.6),
					post * CFrame.new(2.5, 2.6, 0),
					C.leaf,
					soft({ Material = Enum.Material.Grass })
				)
				if k % 2 == 0 then
					ball(
						rowModel,
						"Strugure",
						Vector3.new(0.7, 1.1, 0.7),
						post * CFrame.new(1.6, 1.6, -0.6),
						Color3.fromRGB(96, 44, 110),
						soft()
					)
				end
			end
			local top = (post * CFrame.new(0, 3.8, 0)).Position
			if previous then
				local mid = (previous + top) / 2
				box(
					rowModel,
					"Sarma",
					Vector3.new(0.08, 0.08, (top - previous).Magnitude),
					CFrame.lookAt(mid, top),
					C.tin,
					soft()
				)
			end
			previous = top
		end
	end
end

-- Stâna: țarcul cu oi (Lupii la stână) și coliba ciobanului
builders.stana = function(model, cf)
	local pen = Instance.new("Model")
	pen.Name = "Tarc"
	pen.Parent = model
	for k = 0, 23 do
		local a = k * math.pi / 12
		if k ~= 18 and k ~= 19 then -- poarta țarcului, spre sat
			local p = onGround(cf * CFrame.new(math.cos(a) * 12, 0, math.sin(a) * 12))
			cyl(pen, "Ulucă", 3, 0.4, p * CFrame.new(0, 1.5, 0), C.wood, { Material = Enum.Material.Wood })
			local q =
				onGround(cf * CFrame.new(math.cos(a + math.pi / 12) * 12, 0, math.sin(a + math.pi / 12) * 12))
			local top = (p * CFrame.new(0, 2.4, 0)).Position
			local next = (q * CFrame.new(0, 2.4, 0)).Position
			if k ~= 17 then
				box(
					pen,
					"Sipca",
					Vector3.new(0.3, 0.3, (next - top).Magnitude),
					CFrame.lookAt((top + next) / 2, next),
					C.wood,
					{ Material = Enum.Material.Wood }
				)
			end
		end
	end
	marker(pen, "TarcZona", Vector3.new(20, 6, 20), cf * CFrame.new(0, 3, 0))
	for i = 1, 6 do
		local a = i * 1.05
		local p = onGround(cf * CFrame.new(math.cos(a) * 5, 0, math.sin(a) * 5) * CFrame.Angles(0, a, 0))
		if sculpted(model, "char.Oaia", p, "Oaie") then
			continue
		end
		local sheep = Instance.new("Model")
		sheep.Name = "Oaie"
		sheep.Parent = model
		ball(
			sheep,
			"Lana",
			Vector3.new(2.4, 2, 3.2),
			p * CFrame.new(0, 1.6, 0),
			C.white,
			soft({ Material = Enum.Material.Fabric })
		)
		ball(
			sheep,
			"Cap",
			Vector3.new(1, 1.1, 1.3),
			p * CFrame.new(0, 2, -1.9),
			Color3.fromRGB(60, 52, 48),
			soft()
		)
	end
	local hut = onGround(cf * CFrame.new(18, 0, 6) * CFrame.Angles(0, math.rad(-100), 0))
	if sculpted(model, "world.Stana", hut * CFrame.new(0, 0, 4), "Coliba", 0.7) then
		return
	end
	box(
		model,
		"Coliba",
		Vector3.new(7, 4, 6),
		hut * CFrame.new(0, 2, 0),
		C.darkWood,
		{ Material = Enum.Material.WoodPlanks }
	)
	gable(model, hut * CFrame.new(0, 4, 0), 7, 6, 3.4, C.straw)
end

-- Moara de vânt pe deal: turnul, căciula, palele (rotite pe client: atributul Spin)
builders.moara = function(model, cf)
	if sculpted(model, "world.Moara", cf, nil, 1.3) then
		return
	end
	for i = 0, 3 do
		cyl(
			model,
			"Turn",
			4,
			9 - i * 1.3,
			cf * CFrame.new(0, 2 + i * 4, 0),
			C.wall,
			{ Material = Enum.Material.Plaster }
		)
	end
	ball(
		model,
		"Caciula",
		Vector3.new(6, 4, 6),
		cf * CFrame.new(0, 16.4, 0),
		C.straw,
		{ Material = Enum.Material.Grass }
	)
	box(
		model,
		"UsaMoara",
		Vector3.new(2.6, 4.6, 0.3),
		cf * CFrame.new(0, 2.3, -4.4),
		C.darkWood,
		{ CanCollide = false }
	)
	local hub = cf * CFrame.new(0, 14, -3.8)
	local blades = Instance.new("Model")
	blades.Name = "Pale"
	blades.Parent = model
	local axle = cyl(blades, "Ax", 1.2, 1, hub, C.darkWood)
	blades.PrimaryPart = axle
	for k = 0, 3 do
		local arm = hub * CFrame.Angles(0, 0, k * math.pi / 2)
		box(blades, "Brat", Vector3.new(0.4, 11, 0.3), arm * CFrame.new(0, 5.5, -0.4), C.wood, soft())
		box(
			blades,
			"Panza",
			Vector3.new(2.6, 8, 0.1),
			arm * CFrame.new(1.4, 6.5, -0.45),
			C.white,
			soft({ Material = Enum.Material.Fabric })
		)
	end
	blades:SetAttribute("Spin", 0.6) -- rotații pe secundă (radiani: × 2π), pe client
end

-- Biserica de pe deal: naosul alb, turnul cu bulb aurit, crucea, clopotul
builders.biserica = function(model, cf)
	if sculpted(model, "world.Biserica", cf, nil, 1.2) then
		-- clopotul rămâne ca reper (invizibil), în turla modelului
		local bell = marker(model, "Clopot", Vector3.new(2, 2, 2), cf * CFrame.new(0, 15, -2))
		bell:SetAttribute("Bell", true)
		return
	end
	house(model, cf * CFrame.new(0, 0, 6), 14, 22, 10, C.white, Color3.fromRGB(70, 110, 90))
	box(
		model,
		"Turn",
		Vector3.new(8, 20, 8),
		cf * CFrame.new(0, 10, -9),
		C.white,
		{ Material = Enum.Material.Plaster }
	)
	ball(
		model,
		"Bulb",
		Vector3.new(6.4, 7, 6.4),
		cf * CFrame.new(0, 23, -9),
		C.gold,
		{ Material = Enum.Material.Foil }
	)
	box(model, "CruceV", Vector3.new(0.4, 3.6, 0.4), cf * CFrame.new(0, 28.2, -9), C.gold)
	box(model, "CruceO", Vector3.new(2, 0.4, 0.4), cf * CFrame.new(0, 28.8, -9), C.gold)
	box(
		model,
		"Fereastra",
		Vector3.new(3, 4, 8.2),
		cf * CFrame.new(0, 15, -9),
		Color3.fromRGB(40, 40, 50),
		{ CanCollide = false }
	)
	local bell = ball(
		model,
		"Clopot",
		Vector3.new(2, 2.2, 2),
		cf * CFrame.new(0, 15, -9),
		Color3.fromRGB(176, 130, 60),
		soft({ Material = Enum.Material.Metal })
	)
	bell:SetAttribute("Bell", true)
	box(
		model,
		"Usa",
		Vector3.new(3.2, 6, 0.3),
		cf * CFrame.new(0, 3, -13.1),
		C.darkWood,
		{ CanCollide = false }
	)
	pcall(function()
		(model :: any).LevelOfDetail = (Enum.ModelLevelOfDetail :: any).SLIM
	end)
end

-- Marginea codrului: copaci înalți și întunecați; de aici ies lupii și Muma Pădurii
builders.codru = function(model, cf)
	for i = 1, 26 do
		local x = ((i * 47) % 70) - 35
		local z = ((i * 29) % 30) - 2 + (i % 3) * 4
		local h = 16 + (i % 5) * 3
		local place = onGround(cf * CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(i * 67), 0))
		if
			not sculpted(
				model,
				if i % 3 == 0 then "world.Nuc" else "world.Stejar",
				place * CFrame.new(0, -0.5, 0),
				"Copac",
				0.9 + (i % 4) * 0.12
			)
		then
			tree(model, place, h, if i % 2 == 0 then C.darkLeaf else Color3.fromRGB(48, 96, 50), nil)
		end
	end
	marker(model, "Iesire", Vector3.new(8, 6, 8), cf * CFrame.new(0, 3, -8))
end

-- Gara: clădirea, peronul, linia ferată (est–vest, de-a lungul satului)
builders.gara = function(model, cf)
	if not sculpted(model, "world.Gara", cf * CFrame.new(0, 0, -11), "Gara") then
		house(model, cf * CFrame.new(0, 0, -10), 18, 8, 8, Color3.fromRGB(236, 214, 160), C.tin)
		sign(model, cf * CFrame.new(0, 7.4, -14.2), 6, "site.gara", "GARA")
	end
	box(
		model,
		"Peron",
		Vector3.new(44, 1, 6),
		cf * CFrame.new(0, 0.5, 2),
		C.concrete,
		{ Material = Enum.Material.Concrete }
	)
	local line = Instance.new("Model")
	line.Name = "Linie"
	line.Parent = model
	-- linia e paralelă cu axa X a lumii, la z = Village.railwayZ (la sud de peron)
	local z = Village.railwayZ
	local y = cf.Position.Y
	box(
		line,
		"Terasament",
		Vector3.new(1200, 0.6, 7),
		CFrame.new(0, y + 0.3, z),
		Color3.fromRGB(120, 110, 100),
		{ Material = Enum.Material.Slate }
	)
	for _, side in { -1.6, 1.6 } do
		box(
			line,
			"Sina",
			Vector3.new(1200, 0.4, 0.3),
			CFrame.new(0, y + 0.8, z + side),
			C.tin,
			{ Material = Enum.Material.Metal }
		)
	end
	for x = -60, 60, 3 do
		box(
			line,
			"Traversa",
			Vector3.new(0.8, 0.25, 5),
			CFrame.new(cf.Position.X + x, y + 0.65, z),
			C.darkWood,
			soft({ Material = Enum.Material.Wood })
		)
	end
	marker(line, "Oprire", Vector3.new(40, 6, 6), CFrame.new(cf.Position.X, y + 3, z))
end

-- Bazarul: 8 tarabe în două rânduri, cu copertine în dungi
builders.bazar = function(model, cf)
	local stripes = {
		{ C.red, C.white },
		{ C.blue, C.white },
		{ C.gold, C.red },
		{ Color3.fromRGB(70, 150, 90), C.white },
	}
	for i = 1, 8 do
		local row, col = (i - 1) // 4, (i - 1) % 4
		local stall = cf
			* CFrame.new(-15 + col * 10, 0, -6 + row * 14)
			* CFrame.Angles(0, if row == 1 then math.pi else 0, 0)
		local m = Instance.new("Model")
		m.Name = "Taraba" .. i
		m.Parent = model
		if sculpted(m, "world.Taraba", stall, "TarabaSculptata") then
			marker(m, "Vanzator", Vector3.new(3, 5, 3), stall * CFrame.new(0, 2.5, 2.4))
			continue
		end
		box(
			m,
			"Masa",
			Vector3.new(7, 0.4, 3),
			stall * CFrame.new(0, 3, 0),
			C.wood,
			{ Material = Enum.Material.WoodPlanks }
		)
		box(
			m,
			"MasaFata",
			Vector3.new(7, 2.8, 0.3),
			stall * CFrame.new(0, 1.5, -1.4),
			C.wood,
			{ Material = Enum.Material.WoodPlanks }
		)
		for _, sx in { -3.3, 3.3 } do
			for _, sz in { -1.3, 1.3 } do
				box(m, "Stalp", Vector3.new(0.3, 7, 0.3), stall * CFrame.new(sx, 3.5, sz), C.darkWood)
			end
		end
		local pair = stripes[(i - 1) % #stripes + 1]
		for k = 0, 6 do
			box(
				m,
				"Copertina",
				Vector3.new(1, 0.2, 4),
				stall * CFrame.new(-3 + k, 7.1, -0.2) * CFrame.Angles(math.rad(-10), 0, 0),
				pair[k % 2 + 1],
				soft({ Material = Enum.Material.Fabric })
			)
		end
		marker(m, "Vanzator", Vector3.new(3, 5, 3), stall * CFrame.new(0, 2.5, 2.4))
	end
	sign(model, cf * CFrame.new(0, 9, -9), 6, "site.bazar", "BAZAR")
	for _, sx in { -3, 3 } do
		box(model, "BazarStalp", Vector3.new(0.4, 9, 0.4), cf * CFrame.new(sx, 4.5, -9), C.darkWood)
	end
end

-- Bucătăria de vară: o căsuță deschisă în față, cuptorul de lut, masa
builders.bucatarie = function(model, cf)
	-- bucătăria sculptată (deschisă în față, cu plita și cuptorul înăuntru); pereții rămân coliziuni
	local kitchen = sculpted(model, "world.Bucatarie", cf, "Bucatarie", 1.25)
	box(
		model,
		"PereteSpate",
		Vector3.new(10, 6, 0.6),
		cf * CFrame.new(0, 3, 4),
		C.wall,
		{ Material = Enum.Material.Plaster, Transparency = if kitchen then 1 else 0 }
	)
	for _, side in { -1, 1 } do
		box(
			model,
			"PereteLateral",
			Vector3.new(0.6, 6, 8),
			cf * CFrame.new(side * 5, 3, 0),
			C.wall,
			{ Material = Enum.Material.Plaster, Transparency = if kitchen then 1 else 0 }
		)
	end
	if not kitchen then
		gable(model, cf * CFrame.new(0, 6, 0), 10, 8, 3, C.roof)
	end
	local oven = cf * CFrame.new(9, 0, 1)
	local sculptedOven = sculpted(model, "world.Cuptor", oven, "Cuptor")
	if sculptedOven then
		local fire = Instance.new("PointLight")
		fire.Color = Color3.fromRGB(255, 150, 60)
		fire.Range = 10
		fire.Parent = sculptedOven:FindFirstChildWhichIsA("BasePart", true)
	end
	if not sculptedOven then
		box(
			model,
			"CuptorBaza",
			Vector3.new(5, 2, 5),
			oven * CFrame.new(0, 1, 0),
			C.wall,
			{ Material = Enum.Material.Plaster }
		)
		local dome = ball(
			model,
			"Cuptor",
			Vector3.new(5, 4, 5),
			oven * CFrame.new(0, 2.6, 0),
			Color3.fromRGB(226, 204, 170),
			{ Material = Enum.Material.Plaster }
		)
		box(
			model,
			"GuraCuptor",
			Vector3.new(1.6, 1.2, 0.3),
			oven * CFrame.new(0, 2.8, -2.4),
			Color3.fromRGB(40, 24, 18),
			soft()
		)
		local fire = Instance.new("PointLight")
		fire.Color = Color3.fromRGB(255, 150, 60)
		fire.Range = 10
		fire.Parent = dome
	end
	box(
		model,
		"Masa",
		Vector3.new(6, 0.4, 3),
		cf * CFrame.new(0, 2.6, -7),
		C.wood,
		{ Material = Enum.Material.WoodPlanks }
	)
	for _, sx in { -2.6, 2.6 } do
		box(model, "MasaPicior", Vector3.new(0.4, 2.4, 2.6), cf * CFrame.new(sx, 1.2, -7), C.darkWood)
	end
end

-- Claia de fân: trei căpițe în jurul parului (ascunzători; sar de pe ele copiii)
builders.claie = function(model, cf)
	for i, at in { { 0, 0, 1 }, { -9, 5, 0.75 }, { 8, 6, 0.65 } } do
		local s = at[3]
		local p = cf * CFrame.new(at[1], 0, at[2])
		local art = sculpted(model, "world.Claie", onGround(p), if i == 1 then "Claie" else "Capita", 1.7 * s)
		if art then
			art:SetAttribute("HidingSpot", true)
			continue
		end
		local hay = ball(
			model,
			if i == 1 then "Claie" else "Capita",
			Vector3.new(12, 13, 12) * s,
			p * CFrame.new(0, 5 * s, 0),
			C.straw,
			{ Material = Enum.Material.Grass }
		)
		hay:SetAttribute("HidingSpot", true)
		cyl(model, "Par", 15 * s, 0.4, p * CFrame.new(0, 7 * s, 0), C.darkWood, soft())
	end
end

-- Obiectele de context ale locurilor (cheie, x, z, rotire în grade, scară), relativ la loc (fața spre −Z): satul
-- trăit din jurul reperelor, departe de marcajele jocurilor. Fără model, nimic.
local DRESSING: { [string]: { { any } } } = {
	moara = { -- treptele obby-ului urcă în spirală pe raza 13: obiectele stau dincolo de 18
		{ "world.Saci", -18, 8, 20 },
		{ "world.Caruta", 19, 8, 35 },
		{ "world.Banca", -19, -6, 90 },
		{ "world.Lemne", 14, 18, 180 },
		{ "world.Salcam", -27, 16, 30 },
		{ "world.Tufa", 23, -12, 0 },
		{ "world.Flori", -21, -14, 0 },
	},
	biserica = { -- plopii în spate, nucul în lateral, gardul de uluci în față (cu poarta liberă)
		{ "world.Liliac", -12, -7, 0 },
		{ "world.Liliac", 12, -7, 40 },
		{ "world.Banca", -8, -13, 180 },
		{ "world.Flori", 6, -13, 0 },
		{ "world.Plop", -15, 11, 0 },
		{ "world.Plop", 15, 11, 50 },
		{ "world.Nuc", -27, -2, 60 },
		{ "world.Uluci", -11, -20, 0 },
		{ "world.Uluci", -21, -20, 0 },
		{ "world.Uluci", 11, -20, 0 },
		{ "world.Uluci", 21, -20, 0 },
	},
	stana = {
		{ "world.Lemne", 25, -3, 80 },
		{ "world.Banca", 13, -7, 180 },
		{ "world.Tufa", -14, -11, 0 },
		{ "world.Salcam", -27, 9, 120 },
	},
	gara = { { "world.Saci", 16, -15, 0 }, { "world.Caruta", -17, -14, -25 }, { "world.Liliac", 19, -6, 0 } },
	magazin = { { "world.Banca", -7, -13, 180 }, { "world.Saci", 7, -13, 10 }, { "world.Lemne", 11, 5, 90 } },
	bucatarie = { { "world.Lemne", -10, 5, 0 }, { "world.Saci", 8, -3, 60 } },
	claie = { { "world.Caruta", 2, -12, 70 } },
	statie = { { "world.Flori", 9, -5, 0 }, { "world.Liliac", -9, 3, 0 } },
	bazar = { { "world.Caruta", -21, 9, 20 }, { "world.Saci", 19, 7, 0 } },
	livada = { { "world.Banca", 8, 14, 180 }, { "world.Lemne", -12, 20, 90 } },
}

-- Construiește toate locurile în Workspace.Village.Sites
function SiteBuilder.build(sites: { [string]: CFrame }, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Sites"
	-- întâi platourile: pe deal, locul stă drept (altfel panta neregulată îngroapă clădirile)
	for _, cf in sites do
		local center = cf.Position
		local y = SiteBuilder.groundY(center.X, center.Z)
		if y > 1 then
			local terrain = Workspace.Terrain
			terrain:FillCylinder(CFrame.new(center.X, y + 30, center.Z), 60, 36, Enum.Material.Air)
			terrain:FillCylinder(CFrame.new(center.X, y - 6, center.Z), 12, 38, Enum.Material.Grass)
		end
	end
	-- terenul schimbat se vede în raycast abia după un cadru; apoi clădirile se așază pe el
	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()
	for key, cf in sites do
		local model = Instance.new("Model")
		model.Name = key
		model:SetAttribute("Site", key)
		local base = onGround(CFrame.new(cf.Position.X, 0, cf.Position.Z) * cf.Rotation)
		local anchor = marker(model, "Ancora", Vector3.new(2, 2, 2), base)
		model.PrimaryPart = anchor
		local art = ArtLibrary.get("site." .. key)
		if art then
			art:PivotTo(base)
			art.Parent = model
		elseif builders[key] then
			builders[key](model, base)
		end
		local dressing: { { any } } = DRESSING[key] or {}
		for _, item in dressing do
			prop(
				model,
				item[1],
				base * CFrame.new(item[2], 0, item[3]) * CFrame.Angles(0, math.rad(item[4]), 0),
				item[5]
			)
		end
		-- reperele se văd de oriunde (streaming); de departe, SLIM (înlocuitorul ușor generat de Roblox)
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		pcall(function()
			(model :: any).LevelOfDetail = (Enum.ModelLevelOfDetail :: any).SLIM
		end)
		model.Parent = folder
	end
	folder.Parent = parent
	return folder
end

return SiteBuilder
