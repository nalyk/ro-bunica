--!strict
-- Harta satului (busola atinsă, tasta M): o pânză brodată pe care satul e desenat din planul lui real
-- (VillageLayout): pârâul, iazul, drumurile, podurile, ogrăzile în culoarea familiei (a ta cu aur) și locurile
-- cu semnul lor. Peste ea, stratul viu: tu (săgeata, după cameră), prietenii, rutiera, întâmplarea,
-- mini-jocul la care se intră acum, ținta. Atingi un loc (sau oriunde) → ținta, cu potecă pe pământ
-- (WaypointController); atingi ținta → o ștergi.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local VillageLayout = require(Shared.Domain.VillageLayout)
local MapView = require(Shared.Domain.MapView)
local Compass = require(Shared.Domain.Compass)
local Village = require(Shared.Config.Village)
local World = require(Shared.Config.World)
local Families = require(Shared.Config.Families)
local ClientState = require(script.Parent.ClientState)
local MapMarkers = require(script.Parent.MapMarkers)
local UI = require(script.Parent.UI)

local VillageMap = {}

local LINEN = Color3.fromRGB(244, 233, 210)
local MEADOW = Color3.fromRGB(176, 205, 128)
local WATER = Color3.fromRGB(96, 168, 220)
local ROAD = Color3.fromRGB(214, 184, 134)
local LANE = Color3.fromRGB(196, 166, 118)
local TRAIL = Color3.fromRGB(170, 140, 98)
local STITCH = Color3.fromRGB(196, 36, 48)
local GOLD = Color3.fromRGB(255, 205, 90)
local INK = Color3.fromRGB(60, 40, 32)

local SITE_GLYPH: { [string]: string } = {
	centru = "⛲",
	magazin = "🛒",
	statie = "🚏",
	discoteca = "🪩",
	terenScoala = "⚽",
	iaz = "🎣",
	livada = "🍎",
	lanPorumb = "🌽",
	via = "🍇",
	stana = "🐑",
	moara = "🌾",
	biserica = "⛪",
	codru = "🌳",
	gara = "🚉",
	bazar = "🏪",
	bucatarie = "🍲",
	claie = "🧺",
}

local me = Players.LocalPlayer
local layout = VillageLayout.build()
local overlay: Frame
local card: Frame
local canvas: TextButton
local static: Frame
local live: Frame
local bounds: MapView.Bounds
local canvasSize = Vector2.zero
local liveDots: { [string]: Frame } = {}
local arrow: TextLabel
local opened = false

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0)
	c.Parent = parent
end

local function computeBounds(): MapView.Bounds
	local points = {}
	for _, plot in layout.plots do
		table.insert(points, plot.cframe.Position)
	end
	for _, cf in layout.sites do
		table.insert(points, cf.Position)
	end
	for _, road in layout.roads do
		for _, p in road.points do
			table.insert(points, p)
		end
	end
	return MapView.boundsOf(points, 60)
end

local function at(p: Vector3): Vector2
	return MapView.toMap(bounds, canvasSize, p)
end

-- O linie groasă între două puncte ale hărții
local function line(parent: Instance, a: Vector2, b: Vector2, thickness: number, color: Color3, z: number)
	local d = b - a
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	frame.Size = UDim2.fromOffset(d.Magnitude + thickness * 0.9, thickness)
	frame.Rotation = math.deg(math.atan2(d.Y, d.X))
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.ZIndex = z
	corner(frame)
	frame.Parent = parent
end

local function polyline(points: { Vector3 }, thickness: number, color: Color3, z: number)
	for i = 1, #points - 1 do
		line(static, at(points[i]), at(points[i + 1]), thickness, color, z)
	end
end

local function drawStatic()
	static:ClearAllChildren()
	local scale = MapView.scale(bounds, canvasSize)
	-- pajiștea
	local meadow = Instance.new("Frame")
	meadow.Size = UDim2.fromScale(1, 1)
	meadow.BackgroundColor3 = MEADOW
	meadow.BorderSizePixel = 0
	meadow.ZIndex = 21
	corner(meadow, 10)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(MEADOW, Color3.fromRGB(150, 186, 104))
	shade.Parent = meadow
	meadow.Parent = static
	-- apa
	polyline(layout.river, math.max(3, Village.riverWidth * scale), WATER, 22)
	local pond = layout.sites.iaz
	if pond then
		local c = at(pond.Position)
		local r = math.max(10, 32 * scale)
		local water = Instance.new("Frame")
		water.AnchorPoint = Vector2.new(0.5, 0.5)
		water.Position = UDim2.fromOffset(c.X, c.Y)
		water.Size = UDim2.fromOffset(r * 2, r * 2)
		water.BackgroundColor3 = WATER
		water.ZIndex = 22
		corner(water)
		water.Parent = static
	end
	-- drumurile
	for _, road in layout.trails do
		polyline(road.points, math.max(2, road.width * scale * 0.8), TRAIL, 23)
	end
	for _, road in layout.shortcuts do
		polyline(road.points, math.max(2, road.width * scale * 0.8), LANE, 23)
	end
	for _, road in layout.roads do
		local main = road.name == "drumulMare"
		polyline(road.points, math.max(3, road.width * scale), if main then ROAD else LANE, 24)
	end
	for _, bridge in layout.bridges do
		local c = at(bridge.Position)
		local plank = Instance.new("Frame")
		plank.AnchorPoint = Vector2.new(0.5, 0.5)
		plank.Position = UDim2.fromOffset(c.X, c.Y)
		plank.Size = UDim2.fromOffset(math.max(6, 18 * scale), math.max(4, 10 * scale))
		plank.BackgroundColor3 = Color3.fromRGB(140, 96, 60)
		plank.ZIndex = 25
		corner(plank, 2)
		plank.Parent = static
	end
	-- ogrăzile (culoarea familiei; a ta cu aur)
	local mine = ClientState.state.plotIndex
	local plotsFolder = Workspace:FindFirstChild("Plots") or Workspace
	for index, plot in layout.plots do
		local c = at(plot.cframe.Position)
		local right = plot.cframe.RightVector
		local rect = Instance.new("Frame")
		rect.Name = "Ograda" .. index
		rect.AnchorPoint = Vector2.new(0.5, 0.5)
		rect.Position = UDim2.fromOffset(c.X, c.Y)
		rect.Size = UDim2.fromOffset(World.plotSize.X * scale, World.plotSize.Z * scale)
		rect.Rotation = math.deg(math.atan2(right.Z, right.X))
		local model = plotsFolder:FindFirstChild("Plot" .. index, true)
		local family = model and model:GetAttribute("FamilyId")
		rect.BackgroundColor3 = if type(family) == "number"
			then Families.colors[(family % #Families.colors) + 1]
			else Color3.fromRGB(226, 214, 186)
		rect.BackgroundTransparency = 0.15
		rect.ZIndex = 26
		corner(rect, 4)
		local stroke = Instance.new("UIStroke")
		stroke.Color = if index == mine then GOLD else Color3.fromRGB(120, 90, 60)
		stroke.Thickness = if index == mine then 3 else 1
		stroke.Parent = rect
		rect.Parent = static
		if index == mine then
			local label = Instance.new("TextLabel")
			label.AnchorPoint = Vector2.new(0.5, 1)
			label.Position = UDim2.fromOffset(c.X, c.Y - World.plotSize.Z * scale / 2 - 2)
			label.Size = UDim2.fromOffset(110, 16)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.FredokaOne
			label.TextSize = 13
			label.TextColor3 = INK
			label.TextStrokeColor3 = GOLD
			label.TextStrokeTransparency = 0.2
			label.Text = "🏡 " .. ClientState.t("map.home")
			label.ZIndex = 30
			label.Parent = static
		end
	end
	-- locurile: semnul și numele; atinse → ținta
	for _, key in VillageLayout.SITE_KEYS do
		local cf = layout.sites[key]
		if cf then
			local c = at(cf.Position)
			local chip = Instance.new("TextButton")
			chip.Name = "Loc_" .. key
			chip.AnchorPoint = Vector2.new(0.5, 0.5)
			chip.Position = UDim2.fromOffset(c.X, c.Y)
			chip.Size = UDim2.fromOffset(30, 30)
			chip.BackgroundColor3 = LINEN
			chip.AutoButtonColor = false
			chip.Text = SITE_GLYPH[key] or "•"
			chip.TextScaled = true
			chip.ZIndex = 31
			corner(chip)
			local ring = Instance.new("UIStroke")
			ring.Color = STITCH
			ring.Thickness = 2
			ring.Parent = chip
			chip.Parent = static
			local name = Instance.new("TextLabel")
			name.AnchorPoint = Vector2.new(0.5, 0)
			name.Position = UDim2.new(0.5, 0, 1, 1)
			name.Size = UDim2.fromOffset(96, 14)
			name.BackgroundTransparency = 1
			name.Font = Enum.Font.GothamBold
			name.TextSize = 11
			name.TextColor3 = INK
			name.TextStrokeColor3 = LINEN
			name.TextStrokeTransparency = 0.1
			name.Text = ClientState.t("map.site." .. key)
			name.ZIndex = 31
			name.Parent = chip
			chip.Activated:Connect(function()
				MapMarkers.setWaypoint(cf.Position, ClientState.t("map.site." .. key))
			end)
		end
	end
end

local function dotFor(id: string, glyph: string, color: Color3): Frame
	local existing: Frame? = liveDots[id]
	if existing then
		return existing
	end
	local dot = Instance.new("Frame")
	dot.Name = "Viu_" .. id
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.fromOffset(24, 24)
	dot.BackgroundColor3 = Color3.fromRGB(24, 28, 42)
	dot.ZIndex = 40
	corner(dot)
	local ring = Instance.new("UIStroke")
	ring.Color = color
	ring.Thickness = 2
	ring.Parent = dot
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(0.8, 0.8)
	text.Position = UDim2.fromScale(0.1, 0.1)
	text.TextScaled = true
	text.Text = glyph
	text.ZIndex = 41
	text.Parent = dot
	dot.Parent = live
	liveDots[id] = dot
	return dot
end

local function updateLive()
	if not opened then
		return
	end
	local seen: { [string]: boolean } = {}
	local pulse = (math.sin(os.clock() * 6) + 1) / 2
	for _, marker in MapMarkers.list() do
		if marker.kind ~= "home" then
			seen[marker.id] = true
			local dot = dotFor(marker.id, marker.glyph, marker.color)
			local p = at(marker.position)
			dot.Position = UDim2.fromOffset(p.X, p.Y)
			local grow = if marker.alert then 1 + pulse * 0.25 else 1
			dot.Size = UDim2.fromOffset(24 * grow, 24 * grow)
		end
	end
	for id, dot in liveDots do
		if not seen[id] then
			dot:Destroy()
			liveDots[id] = nil
		end
	end
	local character = me.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = Workspace.CurrentCamera
	arrow.Visible = root ~= nil
	if root and camera then
		local p = at(root.Position)
		arrow.Position = UDim2.fromOffset(p.X, p.Y)
		arrow.Rotation = Compass.heading(camera.CFrame.LookVector)
	end
end

local function layoutCard()
	local screen = UI.screen().AbsoluteSize
	local header, footer, pad = 34, 22, 10
	local ratio = (bounds.maxX - bounds.minX) / (bounds.maxZ - bounds.minZ)
	local maxW, maxH = screen.X * 0.94, screen.Y * 0.9
	local innerH = math.min(maxH - header - footer - 2 * pad, (maxW - 2 * pad) / ratio)
	local innerW = innerH * ratio
	card.Size = UDim2.fromOffset(innerW + 2 * pad, innerH + header + footer + 2 * pad)
	canvas.Position = UDim2.fromOffset(pad, header + pad)
	canvas.Size = UDim2.fromOffset(innerW, innerH)
	canvasSize = Vector2.new(innerW, innerH)
end

local function build()
	bounds = computeBounds()
	overlay = Instance.new("Frame")
	overlay.Name = "HartaSatului"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.45
	overlay.ZIndex = 20
	overlay.Visible = false
	overlay.Active = true
	overlay.Parent = UI.screen()

	card = Instance.new("Frame")
	card.Name = "Panza"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.BackgroundColor3 = LINEN
	card.ZIndex = 20
	corner(card, 16)
	local stitch = Instance.new("UIStroke")
	stitch.Color = STITCH
	stitch.Thickness = 3
	stitch.Parent = card
	card.Parent = overlay

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(14, 6)
	title.Size = UDim2.new(1, -70, 0, 26)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = STITCH
	title.Text = "🧭 " .. ClientState.t("map.title")
	title.ZIndex = 21
	title.Parent = card
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -6, 0, 4)
	close.Size = UDim2.fromOffset(44, 30)
	close.BackgroundColor3 = STITCH
	close.TextColor3 = LINEN
	close.Font = Enum.Font.FredokaOne
	close.TextSize = 20
	close.Text = "X"
	close.ZIndex = 22
	corner(close, 10)
	close.Parent = card
	close.Activated:Connect(function()
		VillageMap.toggle()
	end)
	local hint = Instance.new("TextLabel")
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.new(0, 14, 1, -4)
	hint.Size = UDim2.new(1, -28, 0, 18)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.GothamBold
	hint.TextSize = 13
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = INK
	hint.Text = ClientState.t("map.hint")
	hint.ZIndex = 21
	hint.Parent = card

	canvas = Instance.new("TextButton")
	canvas.Name = "Harta"
	canvas.BackgroundTransparency = 1
	canvas.AutoButtonColor = false
	canvas.Text = ""
	canvas.ZIndex = 21
	canvas.ClipsDescendants = true
	canvas.Parent = card
	static = Instance.new("Frame")
	static.Name = "Desen"
	static.BackgroundTransparency = 1
	static.Size = UDim2.fromScale(1, 1)
	static.ZIndex = 21
	static.Parent = canvas
	live = Instance.new("Frame")
	live.Name = "Viu"
	live.BackgroundTransparency = 1
	live.Size = UDim2.fromScale(1, 1)
	live.ZIndex = 40
	live.Parent = canvas
	arrow = Instance.new("TextLabel")
	arrow.Name = "Tu"
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(26, 26)
	arrow.BackgroundTransparency = 1
	arrow.Text = "▲"
	arrow.TextScaled = true
	arrow.TextColor3 = GOLD
	arrow.TextStrokeColor3 = INK
	arrow.TextStrokeTransparency = 0
	arrow.ZIndex = 45
	arrow.Parent = live

	-- atingere pe hartă: ținta în locul atins; pe țintă: o ștergi
	canvas.InputBegan:Connect(function(input)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		-- InputObject.Position e în același sistem ca AbsolutePosition (fără bara de sus a Roblox)
		local uv = Vector2.new(input.Position.X, input.Position.Y) - canvas.AbsolutePosition
		local current = MapMarkers.waypoint()
		if current and (at(current) - uv).Magnitude < 18 then
			MapMarkers.setWaypoint(nil)
			return
		end
		MapMarkers.setWaypoint(MapView.toWorld(bounds, canvasSize, uv), ClientState.t("map.pin"))
	end)
end

function VillageMap.isOpen(): boolean
	return opened
end

function VillageMap.toggle()
	if not overlay then
		return
	end
	opened = not opened
	overlay.Visible = opened
	-- lista de jucători a Roblox (dreapta sus) ar acoperi colțul hărții
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, not opened)
	if opened then
		layoutCard()
		drawStatic()
		updateLive()
	end
end

-- Pentru playtest
function VillageMap.debugState(): { [string]: any }
	local shown = {}
	for id in liveDots do
		table.insert(shown, id)
	end
	table.sort(shown)
	return {
		open = opened,
		canvas = { canvasSize.X, canvasSize.Y },
		sites = if static then #static:GetChildren() else 0,
		live = shown,
		waypoint = MapMarkers.waypoint(),
	}
end

function VillageMap.start()
	build()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.1 then
			accumulator = 0
			updateLive()
		end
	end)
end

return VillageMap
