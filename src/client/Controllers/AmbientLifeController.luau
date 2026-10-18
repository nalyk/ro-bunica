--!strict
-- Viața satului, doar pe client (Config/Ambient): gâște în stol pe ulicioara centrului, găini în ogrăzi, câini la
-- porți care latră în lanț la un străin noaptea (atributul „Barking” pe câine), trei săteni pe drumuri, berze pe
-- stâlpi și una care plutește peste sat, rufe pe sfoară. Totul e CFrame, fără coliziuni și fără umbre.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ArtLibrary = require(Shared.Visual.ArtLibrary)
local Ambient = require(Shared.Config.Ambient)
local GameState = require(Shared.GameState)
local Sounds = require(Shared.Config.Sounds)
local VillageLayout = require(Shared.Domain.VillageLayout)
local Scatter = require(Shared.Domain.Scatter)
local Sfx = require(script.Parent.Sfx)

local AmbientLifeController = {}

local GROUND = -1
local folder: Folder

-- Construcție ------------------------------------------------------------------------------------------------

local function piece(
	model: Model,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	offset: CFrame,
	color: Color3
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p:SetAttribute("Offset", offset)
	p.Parent = model
	return p
end

local BLOCK, BALL, CYL = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder
local WHITE, ORANGE = Color3.fromRGB(246, 246, 240), Color3.fromRGB(240, 150, 40)

local function newModel(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = folder
	return model
end

-- Figura sculptată (TRELLIS) ca piese cu Offset, ca `place` să o miște la fel ca pe cele simple; nil dacă lipsește
local function sculptedFigure(name: string, key: string): Model?
	local art = ArtLibrary.get(key)
	if not art then
		return nil
	end
	art:PivotTo(CFrame.new())
	local box, size = art:GetBoundingBox()
	art:PivotTo(CFrame.new(-box.X, -(box.Y - size.Y / 2), -box.Z))
	local m = newModel(name)
	for _, part in art:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part:SetAttribute("Offset", part.CFrame)
			part.Parent = m
		end
	end
	art:Destroy()
	return m
end

local function goose(): Model
	local art = sculptedFigure("Gasca", "char.Gasca")
	if art then
		return art
	end
	local m = newModel("Gasca")
	piece(m, "Corp", BALL, Vector3.new(1.4, 1.2, 2), CFrame.new(0, 0.9, 0), WHITE)
	piece(
		m,
		"Gat",
		CYL,
		Vector3.new(1.3, 0.4, 0.4),
		CFrame.new(0, 1.7, -0.8) * CFrame.Angles(0, 0, math.pi / 2),
		WHITE
	)
	piece(m, "Cap", BALL, Vector3.new(0.6, 0.6, 0.7), CFrame.new(0, 2.4, -0.9), WHITE)
	piece(m, "Cioc", BLOCK, Vector3.new(0.25, 0.2, 0.5), CFrame.new(0, 2.35, -1.35), ORANGE)
	return m
end

local function hen(): Model
	local art = sculptedFigure("Gaina", "char.Gaina")
	if art then
		return art
	end
	local m = newModel("Gaina")
	local brown = Color3.fromRGB(176, 110, 60)
	piece(m, "Corp", BALL, Vector3.new(0.9, 0.9, 1.2), CFrame.new(0, 0.6, 0), brown)
	piece(m, "Cap", BALL, Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 1.15, -0.5), brown)
	piece(
		m,
		"Creasta",
		BLOCK,
		Vector3.new(0.1, 0.25, 0.3),
		CFrame.new(0, 1.45, -0.5),
		Color3.fromRGB(220, 40, 40)
	)
	piece(m, "Cioc", BLOCK, Vector3.new(0.15, 0.12, 0.25), CFrame.new(0, 1.1, -0.8), ORANGE)
	return m
end

local function dog(): Model
	local m = newModel("Caine")
	local fur = Color3.fromRGB(150, 110, 70)
	piece(m, "Corp", BLOCK, Vector3.new(1.2, 1.1, 2.6), CFrame.new(0, 1.3, 0), fur)
	piece(m, "Cap", BLOCK, Vector3.new(1, 1, 1.1), CFrame.new(0, 2.1, -1.5), fur)
	piece(m, "Bot", BLOCK, Vector3.new(0.6, 0.5, 0.6), CFrame.new(0, 1.9, -2.2), Color3.fromRGB(60, 44, 36))
	for _, side in { -0.35, 0.35 } do
		piece(
			m,
			"Ureche",
			BLOCK,
			Vector3.new(0.25, 0.5, 0.2),
			CFrame.new(side, 2.7, -1.4),
			Color3.fromRGB(90, 64, 44)
		)
		piece(m, "LabaF", BLOCK, Vector3.new(0.3, 0.8, 0.3), CFrame.new(side, 0.4, -0.9), fur)
		piece(m, "LabaS", BLOCK, Vector3.new(0.3, 0.8, 0.3), CFrame.new(side, 0.4, 0.9), fur)
	end
	piece(
		m,
		"Coada",
		BLOCK,
		Vector3.new(0.2, 0.2, 0.9),
		CFrame.new(0, 1.9, 1.5) * CFrame.Angles(math.rad(30), 0, 0),
		fur
	)
	return m
end

local villagerCount = 0
local function villager(shirt: Color3): Model
	villagerCount += 1
	local art = sculptedFigure("Satean", "char.Satean" .. ((villagerCount - 1) % 3 + 1))
	if art then
		return art
	end
	local m = newModel("Satean")
	local skin = Color3.fromRGB(234, 196, 160)
	piece(m, "Trup", BLOCK, Vector3.new(1.8, 2, 1), CFrame.new(0, 3, 0), shirt)
	piece(m, "Cap", BLOCK, Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, 4.6, 0), skin)
	piece(
		m,
		"Palarie",
		CYL,
		Vector3.new(0.3, 1.8, 1.8),
		CFrame.new(0, 5.25, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(50, 44, 40)
	)
	piece(m, "PiciorS", BLOCK, Vector3.new(0.8, 2, 0.8), CFrame.new(-0.45, 1, 0), Color3.fromRGB(60, 60, 70))
	piece(m, "PiciorD", BLOCK, Vector3.new(0.8, 2, 0.8), CFrame.new(0.45, 1, 0), Color3.fromRGB(60, 60, 70))
	return m
end

local function stork(): Model
	local m = newModel("Barza")
	piece(m, "Corp", BALL, Vector3.new(1.2, 1.2, 2), CFrame.new(0, 2.2, 0), WHITE)
	piece(
		m,
		"AripaS",
		BLOCK,
		Vector3.new(0.2, 0.6, 1.6),
		CFrame.new(-0.6, 2.3, 0.2),
		Color3.fromRGB(30, 30, 30)
	)
	piece(
		m,
		"AripaD",
		BLOCK,
		Vector3.new(0.2, 0.6, 1.6),
		CFrame.new(0.6, 2.3, 0.2),
		Color3.fromRGB(30, 30, 30)
	)
	piece(m, "Gat", BLOCK, Vector3.new(0.25, 1.2, 0.25), CFrame.new(0, 3.1, -0.8), WHITE)
	piece(
		m,
		"Cioc",
		BLOCK,
		Vector3.new(0.15, 0.15, 1.1),
		CFrame.new(0, 3.6, -1.4),
		Color3.fromRGB(220, 60, 40)
	)
	piece(
		m,
		"PiciorS",
		BLOCK,
		Vector3.new(0.12, 1.6, 0.12),
		CFrame.new(-0.25, 0.8, 0),
		Color3.fromRGB(220, 60, 40)
	)
	piece(
		m,
		"PiciorD",
		BLOCK,
		Vector3.new(0.12, 1.6, 0.12),
		CFrame.new(0.25, 0.8, 0),
		Color3.fromRGB(220, 60, 40)
	)
	return m
end

-- Pune modelul la `cf` (fiecare piesă are offset-ul ei în atribute: fără PivotTo, mai ieftin)
local function place(model: Model, cf: CFrame, extra: { [string]: CFrame }?)
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			local offset = child:GetAttribute("Offset") :: CFrame
			local more = extra and extra[child.Name]
			child.CFrame = cf * offset * (more or CFrame.identity)
		end
	end
end

-- Drumuri: punctul de la fracțiunea `t` (0–1) din lungimea poliliniei, cu direcția
type Path = { points: { Vector3 }, lengths: { number }, total: number }

local function path(points: { Vector3 }): Path
	local lengths, total = {}, 0
	for i = 1, #points - 1 do
		local d = (points[i + 1] - points[i]).Magnitude
		table.insert(lengths, d)
		total += d
	end
	return { points = points, lengths = lengths, total = total }
end

local function along(p: Path, t: number): (Vector3, Vector3)
	local distance = math.clamp(t, 0, 1) * p.total
	for i, d in p.lengths do
		if distance <= d or i == #p.lengths then
			local a, b = p.points[i], p.points[i + 1]
			local dir = (b - a).Unit
			return a:Lerp(b, math.clamp(distance / math.max(d, 1e-3), 0, 1)), dir
		end
		distance -= d
	end
	return p.points[1], Vector3.new(0, 0, -1)
end

local function flatAt(position: Vector3, dir: Vector3, y: number): CFrame
	local p = Vector3.new(position.X, y, position.Z)
	local look = Vector3.new(dir.X, 0, dir.Z)
	return if look.Magnitude > 1e-3 then CFrame.lookAt(p, p + look) else CFrame.new(p)
end

-- Starea --------------------------------------------------------------------------------------------------------

type Flock = { path: Path, t: number, direction: number, members: { Model } }
type Hen = { model: Model, plotCf: CFrame, at: Vector2, target: Vector2, wait: number, rng: () -> number }
type Dog = {
	model: Model,
	cf: CFrame,
	gate: Vector3,
	plot: Model,
	index: number,
	lane: string,
	until_: number,
	nextBark: number,
	cooldown: number,
}
type Walker = { model: Model, path: Path, t: number, direction: number, speed: number }
type Cloth = { part: Part, base: CFrame, phase: number }

local flock: Flock? = nil
local hens: { Hen } = {}
local dogs: { Dog } = {}
local walkers: { Walker } = {}
local storks: { { model: Model?, cf: CFrame, phase: number } } = {}
local flyer: Model? = nil
local cloths: { Cloth } = {}

local function plotCFrame(plot: Model): CFrame?
	local ground = plot:FindFirstChild("Ground") :: BasePart?
	return if ground then ground.CFrame * CFrame.new(0, 0.5, 0) else nil
end

-- Pentru playtest: câinii care latră acum
function AmbientLifeController.barking(): number
	local n = 0
	for _, d in dogs do
		if d.model:GetAttribute("Barking") == true then
			n += 1
		end
	end
	return n
end

function AmbientLifeController.counts(): { [string]: number }
	return {
		geese = if flock then #flock.members else 0,
		hens = #hens,
		dogs = #dogs,
		villagers = #walkers,
		storks = #storks,
	}
end

local function build(village: Instance)
	local layout = VillageLayout.build()
	local roads: { [string]: { Vector3 } } = {}
	for _, road in layout.roads do
		roads[road.name] = road.points
	end
	-- gâștele, pe ulicioara centrului
	local members = {}
	for _ = 1, Ambient.geese.count do
		table.insert(members, goose())
	end
	flock = { path = path(roads.ulicioaraCentrului), t = 0.2, direction = 1, members = members }
	-- găinile, câinii și rufele: pentru fiecare ogradă, când ajunge pe client (streaming)
	local function addPlot(index: number, spot: VillageLayout.PlotSpot, plot: Model)
		local cf = plotCFrame(plot)
		if not cf then
			return
		end
		local rng = Scatter.rng(index * 977)
		local area = Ambient.hens.area
		for _ = 1, Ambient.hensPerYard do
			local at = area.min
				+ Vector2.new(rng() * (area.max.X - area.min.X), rng() * (area.max.Y - area.min.Y))
			table.insert(
				hens,
				{ model = hen(), plotCf = cf, at = at, target = at, wait = rng() * 3, rng = rng }
			)
		end
		local dogCf = cf * CFrame.new(Ambient.dog.spot) * CFrame.Angles(0, math.rad(180 + 25), 0)
		local d = dog()
		place(d, dogCf)
		table.insert(dogs, {
			model = d,
			cf = dogCf,
			gate = (cf * CFrame.new(0, 0, -35)).Position,
			plot = plot,
			index = index,
			lane = spot.lane,
			until_ = 0,
			nextBark = 0,
			cooldown = 0,
		})
		if index % 2 == 1 then
			local laundry = Ambient.laundry
			local line = newModel("Rufe")
			for _, end_ in { laundry.from, laundry.to } do
				piece(
					line,
					"Par",
					BLOCK,
					Vector3.new(0.3, 5, 0.3),
					CFrame.new(0, 2.5, 0),
					Color3.fromRGB(110, 80, 50)
				).CFrame = cf
					* CFrame.new(end_ + Vector3.new(0, 2.5, 0))
			end
			local a, b =
				(cf * CFrame.new(laundry.from + Vector3.new(0, 4.6, 0))).Position,
				(cf * CFrame.new(laundry.to + Vector3.new(0, 4.6, 0))).Position
			piece(
				line,
				"Sfoara",
				BLOCK,
				Vector3.new(0.06, 0.06, (b - a).Magnitude),
				CFrame.identity,
				Color3.fromRGB(230, 230, 220)
			).CFrame =
				CFrame.lookAt((a + b) / 2, b)
			local colors = {
				Color3.fromRGB(230, 70, 70),
				WHITE,
				Color3.fromRGB(80, 130, 210),
				Color3.fromRGB(240, 200, 60),
				Color3.fromRGB(120, 190, 120),
			}
			for k = 1, laundry.items do
				local hang = a:Lerp(b, k / (laundry.items + 1))
				local cloth = piece(
					line,
					"Haina",
					BLOCK,
					Vector3.new(1.6, 2, 0.08),
					CFrame.identity,
					colors[(k + index) % #colors + 1]
				)
				local base = CFrame.lookAt(hang, hang + (b - a).Unit:Cross(Vector3.yAxis))
					* CFrame.new(0, -1, 0)
				cloth.CFrame = base
				table.insert(cloths, { part = cloth, base = base, phase = k * 1.3 + index })
			end
		end
	end
	for index, spot in layout.plots do
		local existing = village:FindFirstChild("Plot" .. index) :: Model?
		if existing then
			addPlot(index, spot, existing)
		else
			local connection: RBXScriptConnection
			connection = village.ChildAdded:Connect(function(child)
				if child.Name == "Plot" .. index and child:IsA("Model") then
					connection:Disconnect()
					task.wait() -- piesele ogrăzii sosesc odată cu ea (Atomic)
					addPlot(index, spot, child)
				end
			end)
		end
	end
	-- sătenii
	for _, def in Ambient.villagers do
		local points = roads[def.route]
		if points then
			local walker = {
				model = villager(def.shirt),
				path = path(points),
				t = def.from,
				direction = 1,
				speed = def.speed,
			}
			walker.model:SetAttribute("From", def.from)
			walker.model:SetAttribute("To", def.to)
			table.insert(walkers, walker)
		end
	end
	-- berzele: pe stâlpii cu cuib și una în zbor peste sat
	-- (cu streaming, stâlpii depărtați sosesc mai târziu: fiecare primește barza când apare, o singură dată)
	local scatter = village:WaitForChild("Scatter", 30)
	local nested: { [Vector3]: boolean } = {}
	local function addStork(item: Instance)
		-- doar stâlpii (Scatter are și sute de copaci sculptați: niciun WaitForChild pe ei)
		if item.Name ~= "StalpBarza" and item.Name ~= "Stalp" then
			return
		end
		local pole = if item:IsA("Model") then item:WaitForChild("Stalp", 10) or item else item
		if pole:IsA("BasePart") and pole:GetAttribute("Stork") and not nested[pole.Position] then
			nested[pole.Position] = true
			local phase = #storks + 1
			local cf = CFrame.new(pole.Position + Vector3.new(0, pole.Size.Y / 2 + 0.6, 0))
				* CFrame.Angles(0, phase, 0)
			-- pe stâlpul sculptat barza e deja în model (cu cuibul): doar o numărăm
			local s = if pole:GetAttribute("Sculpted") then nil else stork()
			if s then
				place(s, cf)
			end
			table.insert(storks, { model = s, cf = cf, phase = phase })
		end
	end
	if scatter then
		for _, pole in scatter:GetChildren() do
			addStork(pole)
		end
		scatter.ChildAdded:Connect(addStork)
	end
	flyer = stork()
end

-- Animația -------------------------------------------------------------------------------------------------------

local function updateDogs(now: number)
	local night = GameState.get(GameState.Attributes.Phase) == "Night"
	local triggered: Dog? = nil
	if night then
		local positions = {}
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				table.insert(positions, { position = root.Position, userId = player.UserId })
			end
		end
		for _, child in Workspace:GetChildren() do
			if
				child:IsA("Model")
				and child.Name ~= "Bunica"
				and child:FindFirstChildOfClass("Humanoid") ~= nil
				and not Players:GetPlayerFromCharacter(child)
			then
				local root = child:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					table.insert(positions, { position = root.Position, userId = -1 })
				end
			end
		end
		for _, d in dogs do
			local owner = d.plot:GetAttribute("OwnerUserId")
			for _, entry in positions do
				if
					entry.userId ~= owner
					and (entry.position - d.gate).Magnitude < Ambient.dog.barkDistance
				then
					if now >= d.cooldown then
						triggered = d
					end
					d.until_ = math.max(d.until_, now + 2.5)
				end
			end
		end
	end
	-- alarma în lanț de pe server: un hoț cu creatura în brațe a trecut pe lângă ogradă (BarkUntil)
	local serverNow = Workspace:GetServerTimeNow()
	for _, d in dogs do
		local barkUntil = d.plot:GetAttribute("BarkUntil")
		if typeof(barkUntil) == "number" and barkUntil > serverNow then
			if now >= d.cooldown then
				triggered = triggered or d
			end
			d.until_ = math.max(d.until_, now + (barkUntil - serverNow))
		end
	end
	-- lanțul: câinii de pe aceeași uliță se iau după el, cu întârziere după depărtare
	if triggered then
		triggered.cooldown = now + Ambient.dog.barkCooldown
		for _, d in dogs do
			if d ~= triggered and d.lane == triggered.lane then
				local hops = math.abs(d.index - triggered.index)
				d.until_ = math.max(d.until_, now + hops * Ambient.dog.chainDelay + 2)
				d.nextBark = math.max(d.nextBark, now + hops * Ambient.dog.chainDelay)
			end
		end
		Sfx.play(Sounds.dogBark, triggered.gate, 0.55, 0.95 + math.random() * 0.15)
	end
	for _, d in dogs do
		local barking = now < d.until_ and now >= d.nextBark
		if d.model:GetAttribute("Barking") ~= barking then
			d.model:SetAttribute("Barking", barking)
		end
		local hop = if barking then math.abs(math.sin(now * 14)) * 0.35 else 0
		local wag = math.sin(now * (if barking then 18 else 5)) * 0.5
		place(d.model, d.cf * CFrame.new(0, hop, 0), {
			Coada = CFrame.Angles(0, wag, 0),
			Cap = CFrame.Angles(if barking then math.rad(-15) else 0, 0, 0),
		})
	end
end

local accumulator = 0
local function step(dt: number)
	accumulator += dt
	local period = 1 / Ambient.updateHz
	if accumulator < period then
		return
	end
	local elapsed = accumulator
	accumulator = 0
	local now = os.clock()
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local near = Ambient.nearDistance

	local f = flock
	if f then
		f.t += f.direction * Ambient.geese.speed * elapsed / f.path.total
		if f.t > 0.95 or f.t < 0.05 then
			f.direction = -f.direction
			f.t = math.clamp(f.t, 0.05, 0.95)
		end
		for k, member in f.members do
			local t = f.t - f.direction * (k - 1) * Ambient.geese.spacing / f.path.total
			local position, dir = along(f.path, t)
			local side = ((k % 2) * 2 - 1) * math.min(k - 1, 2) * 0.9
			local cf = flatAt(position, dir * f.direction, GROUND)
				* CFrame.new(side, math.abs(math.sin(now * 6 + k)) * 0.12, 0)
			place(member, cf * CFrame.Angles(0, 0, math.sin(now * 6 + k) * 0.08))
		end
	end

	for _, h in hens do
		local world = h.plotCf * CFrame.new(h.at.X, 0, h.at.Y)
		if (world.Position - eye).Magnitude > near then
			continue
		end
		local to = h.target - h.at
		if to.Magnitude < 0.2 then
			h.wait -= elapsed
			if h.wait <= 0 then
				local area = Ambient.hens.area
				h.target = area.min
					+ Vector2.new(h.rng() * (area.max.X - area.min.X), h.rng() * (area.max.Y - area.min.Y))
				h.wait = 1 + h.rng() * 3
			end
			local peck = math.max(0, math.sin(now * 9 + h.at.X)) * 0.35
			place(
				h.model,
				world,
				{ Cap = CFrame.new(0, -peck, -peck * 0.6), Cioc = CFrame.new(0, -peck, -peck * 0.6) }
			)
		else
			h.at += to.Unit * math.min(to.Magnitude, Ambient.hens.speed * elapsed)
			local p = h.plotCf * Vector3.new(h.at.X, 0, h.at.Y)
			local look = h.plotCf:VectorToWorldSpace(Vector3.new(to.X, 0, to.Y))
			place(
				h.model,
				flatAt(p, look, h.plotCf.Position.Y) * CFrame.new(0, math.abs(math.sin(now * 10)) * 0.1, 0)
			)
		end
	end

	updateDogs(now)

	for _, w in walkers do
		local from = w.model:GetAttribute("From") :: number
		local to = w.model:GetAttribute("To") :: number
		w.t += w.direction * w.speed * elapsed / w.path.total
		if w.t > to or w.t < from then
			w.direction = -w.direction
			w.t = math.clamp(w.t, from, to)
		end
		local position, dir = along(w.path, w.t)
		if (position - eye).Magnitude > near * 1.5 then
			continue
		end
		local swing = math.sin(now * 7) * 0.5
		place(w.model, flatAt(position, dir * w.direction, GROUND) * CFrame.new(3, 0, 0), {
			PiciorS = CFrame.new(0, 1, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -1, 0),
			PiciorD = CFrame.new(0, 1, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -1, 0),
		})
	end

	for _, s in storks do
		local model = s.model
		if not model then
			continue
		end
		local clatter = if math.sin(now * 0.5 + s.phase) > 0.9 then math.sin(now * 30) * 0.2 else 0
		place(model, s.cf, { Cioc = CFrame.Angles(clatter, 0, 0), Gat = CFrame.Angles(clatter * 0.5, 0, 0) })
	end
	local fly = flyer
	if fly then
		local def = Ambient.stork
		local angle = now * math.pi * 2 / def.circleSeconds
		local center = Vector3.new(15, def.circleHeight, 75)
		local p = center
			+ Vector3.new(
				math.cos(angle) * def.circleRadius,
				math.sin(angle * 3) * 4,
				math.sin(angle) * def.circleRadius
			)
		local dir = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local flap = math.sin(now * 5) * 0.6
		place(fly, CFrame.lookAt(p, p + dir), {
			AripaS = CFrame.Angles(0, 0, flap) * CFrame.new(-1.2, 0, 0),
			AripaD = CFrame.Angles(0, 0, -flap) * CFrame.new(1.2, 0, 0),
		})
	end

	for _, c in cloths do
		c.part.CFrame = c.base
			* CFrame.new(0, 1, 0)
			* CFrame.Angles(math.sin(now * 1.7 + c.phase) * 0.18, 0, 0)
			* CFrame.new(0, -1, 0)
	end
end

function AmbientLifeController.start()
	folder = Instance.new("Folder")
	folder.Name = "AmbientLife"
	folder.Parent = Workspace
	task.spawn(function()
		local village = Workspace:WaitForChild("Village")
		build(village)
		RunService.Heartbeat:Connect(step)
	end)
end

return AmbientLifeController
