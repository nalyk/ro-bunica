--!strict
-- Busola-bandă din HUD: o capsulă de sticlă cu bordură brodată, gradații la 15°, punctele cardinale și
-- semnele vii ale satului (MapMarkers) care alunecă după cum se întoarce camera. Semnele fixate (ograda,
-- ținta, întâmplarea) rămân pe margine, cu săgeată, când sunt în spate; alertele pulsează; sub fiecare semn
-- stă distanța sau numărătoarea. Atinsă (sau tasta M), deschide harta satului (VillageMap).

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Compass = require(Shared.Domain.Compass)
local UiIcons = require(Shared.Config.UiIcons)
local ClientState = require(script.Parent.ClientState)
local MapMarkers = require(script.Parent.MapMarkers)
local VillageMap = require(script.Parent.VillageMap)
local UI = require(script.Parent.UI)

local CompassBar = {}

local HALF_FOV = 75
local TICK_STEP = 15
local CHIP = 26
local ROW_GAP = 30
local GLASS = Color3.fromRGB(18, 22, 36)
local GOLD = Color3.fromRGB(255, 205, 90)
local STITCH = Color3.fromRGB(205, 40, 52)
local INK = Color3.fromRGB(246, 238, 220)

local me = Players.LocalPlayer
local root: Frame
local band: Frame
local layer: Frame
local ticks: { Frame } = {}
local cardinals: { [string]: TextLabel } = {}
type Chip = { frame: Frame, ring: UIStroke, glow: Frame, caption: TextLabel, arrow: TextLabel, seen: boolean }
local chips: { [string]: Chip } = {}
local markers: { MapMarkers.Marker } = {}
local smoothHeading: number? = nil

local function corner(parent: Instance, radius: UDim?)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(1, 0)
	c.Parent = parent
end

local function build()
	root = Instance.new("Frame")
	root.Name = "Busola"
	root.BackgroundColor3 = GLASS
	root.BackgroundTransparency = 0.28
	root.ZIndex = 5
	corner(root)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Parent = root
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, STITCH),
		ColorSequenceKeypoint.new(0.5, GOLD),
		ColorSequenceKeypoint.new(1, STITCH),
	})
	gradient.Parent = stroke
	-- lumina de sticlă de sus
	local sheen = Instance.new("Frame")
	sheen.Name = "Luciu"
	sheen.BackgroundColor3 = Color3.new(1, 1, 1)
	sheen.BackgroundTransparency = 0.88
	sheen.Size = UDim2.new(1, -16, 0.42, 0)
	sheen.Position = UDim2.fromOffset(8, 2)
	sheen.ZIndex = 5
	corner(sheen)
	sheen.Parent = root

	band = Instance.new("Frame")
	band.Name = "Banda"
	band.BackgroundTransparency = 1
	band.ClipsDescendants = true
	band.Size = UDim2.new(1, -20, 1, 0)
	band.Position = UDim2.fromOffset(10, 0)
	band.ZIndex = 6
	band.Parent = root
	local fade = Instance.new("UIGradient") -- semnele se sting spre margini
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.12, 0),
		NumberSequenceKeypoint.new(0.88, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = band

	for i = 1, math.floor(HALF_FOV * 2 / TICK_STEP) + 2 do
		local tick = Instance.new("Frame")
		tick.Name = "Gradatie"
		tick.AnchorPoint = Vector2.new(0.5, 1)
		tick.BackgroundColor3 = INK
		tick.BackgroundTransparency = 0.45
		tick.BorderSizePixel = 0
		tick.Size = UDim2.fromOffset(2, 6)
		tick.ZIndex = 6
		tick.Parent = band
		ticks[i] = tick
	end
	for _, id in { "N", "NE", "E", "SE", "S", "SV", "V", "NV" } do
		local label = Instance.new("TextLabel")
		label.Name = "Cardinal" .. id
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.Text = ClientState.t("compass." .. id)
		label.TextColor3 = if id == "N" then Color3.fromRGB(255, 90, 90) else INK
		label.TextTransparency = if #id == 2 then 0.35 else 0
		label.TextScaled = true
		label.Size = UDim2.new(0, 30, 0.42, 0)
		label.ZIndex = 7
		label.Visible = false
		label.Parent = band
		cardinals[id] = label
	end
	-- crestătura din mijloc
	local notch = Instance.new("TextLabel")
	notch.Name = "Crestatura"
	notch.AnchorPoint = Vector2.new(0.5, 0)
	notch.Position = UDim2.new(0.5, 0, 0, -9)
	notch.Size = UDim2.fromOffset(18, 14)
	notch.BackgroundTransparency = 1
	notch.Text = "▼"
	notch.TextScaled = true
	notch.TextColor3 = GOLD
	notch.ZIndex = 9
	notch.Parent = root

	-- semnele stau într-un strat neclipit: rândurile în plus coboară sub bandă
	layer = Instance.new("Frame")
	layer.Name = "Semne"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.new(1, -20, 1, 0)
	layer.Position = UDim2.fromOffset(10, 0)
	layer.ZIndex = 8
	layer.Parent = root

	local tap = Instance.new("TextButton")
	tap.Name = "DeschideHarta"
	tap.BackgroundTransparency = 1
	tap.Text = ""
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = 10
	tap.Parent = root
	tap.Activated:Connect(function()
		VillageMap.toggle()
	end)
	root.Parent = UI.screen()
end

local function chipFor(marker: MapMarkers.Marker): Chip
	local existing = chips[marker.id]
	if existing then
		return existing
	end
	local frame = Instance.new("Frame")
	frame.Name = "Semn_" .. marker.id
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(CHIP, CHIP)
	frame.BackgroundColor3 = GLASS
	frame.BackgroundTransparency = 0.05
	frame.ZIndex = 9
	corner(frame)
	local ring = Instance.new("UIStroke")
	ring.Thickness = 2
	ring.Parent = frame
	local glow = Instance.new("Frame") -- pulsul alertelor
	glow.Name = "Puls"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1, 1)
	glow.BackgroundTransparency = 1
	glow.ZIndex = 8
	corner(glow)
	glow.Parent = frame
	local id = marker.icon and UiIcons[marker.icon]
	if id then
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Image = "rbxassetid://" .. id
		image.Size = UDim2.fromScale(0.78, 0.78)
		image.Position = UDim2.fromScale(0.11, 0.11)
		image.ZIndex = 10
		image.Parent = frame
	else
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Text = marker.glyph
		text.TextScaled = true
		text.Size = UDim2.fromScale(0.8, 0.8)
		text.Position = UDim2.fromScale(0.1, 0.1)
		text.ZIndex = 10
		text.Parent = frame
	end
	local caption = Instance.new("TextLabel")
	caption.Name = "Distanta"
	caption.AnchorPoint = Vector2.new(0.5, 0)
	caption.Position = UDim2.new(0.5, 0, 1, -1)
	caption.Size = UDim2.fromOffset(52, 12)
	caption.BackgroundTransparency = 1
	caption.Font = Enum.Font.GothamBold
	caption.TextSize = 11
	caption.TextColor3 = INK
	caption.TextStrokeTransparency = 0.4
	caption.ZIndex = 10
	caption.Parent = frame
	local arrow = Instance.new("TextLabel")
	arrow.Name = "Sageata"
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(12, 14)
	arrow.BackgroundTransparency = 1
	arrow.TextScaled = true
	arrow.ZIndex = 10
	arrow.Visible = false
	arrow.Parent = frame
	frame.Parent = layer
	local chip =
		{ frame = frame, ring = ring :: any, glow = glow, caption = caption, arrow = arrow, seen = true }
	chips[marker.id] = chip
	return chip
end

local function update()
	local camera = Workspace.CurrentCamera
	if not camera or not root.Visible then
		return
	end
	local look = camera.CFrame.LookVector
	local target = Compass.heading(look)
	-- direcția netezită (fără tremur), trecând corect peste nord
	smoothHeading = if smoothHeading
		then (smoothHeading + Compass.delta(target, smoothHeading) * 0.35) % 360
		else target
	local heading = smoothHeading :: number
	local width = band.AbsoluteSize.X
	local height = band.AbsoluteSize.Y
	if width <= 0 then
		return
	end
	-- gradațiile
	local first = math.ceil((heading - HALF_FOV) / TICK_STEP) * TICK_STEP
	for i, tick in ticks do
		local angle = first + (i - 1) * TICK_STEP
		local x = Compass.place(Compass.delta(angle % 360, heading), HALF_FOV, width)
		tick.Visible = x ~= nil and angle % 45 ~= 0
		if x then
			tick.Position = UDim2.fromOffset(width / 2 + x, height - 4)
		end
	end
	local visible: { [string]: number } = {}
	for _, mark in Compass.cardinals(heading, HALF_FOV) do
		visible[mark.id] = mark.delta
	end
	for id, label in cardinals do
		local delta = visible[id]
		label.Visible = delta ~= nil
		if delta then
			label.Position = UDim2.new(0, width / 2 + delta / HALF_FOV * width / 2, 0.36, 0)
		end
	end
	-- semnele
	local character = me.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local from = if rootPart then rootPart.Position else camera.CFrame.Position
	local placed = {}
	local seen: { [string]: boolean } = {}
	for _, marker in markers do
		local delta = Compass.delta(Compass.bearing(from, marker.position), heading)
		local x, edge = Compass.place(delta, HALF_FOV, width - CHIP, marker.pinned)
		if x then
			seen[marker.id] = true
			table.insert(placed, {
				id = marker.id,
				x = x,
				priority = marker.priority,
				marker = marker,
				edge = edge,
				delta = delta,
			})
		end
	end
	local rows = Compass.rows(placed :: any, CHIP + 4)
	local now = Workspace:GetServerTimeNow()
	local pulse = (math.sin(os.clock() * 6) + 1) / 2
	for _, item in placed do
		local marker = item.marker :: MapMarkers.Marker
		local chip = chipFor(marker)
		local row = rows[item.id] or 0
		chip.frame.Visible = true
		chip.frame.Position = UDim2.fromOffset(width / 2 + item.x, height / 2 - 4 + row * ROW_GAP)
		chip.ring.Color = marker.color
		if marker.alert then
			chip.glow.BackgroundColor3 = marker.color
			chip.glow.BackgroundTransparency = 0.45 + pulse * 0.5
			chip.glow.Size = UDim2.fromScale(1.25 + pulse * 0.6, 1.25 + pulse * 0.6)
		else
			chip.glow.BackgroundTransparency = 1
		end
		if marker.endsAt and marker.endsAt > now then
			local left = math.floor(marker.endsAt - now)
			chip.caption.Text = string.format("%d:%02d", left // 60, left % 60)
			chip.caption.TextColor3 = marker.color
		else
			chip.caption.Text = tostring(Compass.metres((marker.position - from).Magnitude)) .. " m"
			chip.caption.TextColor3 = INK
		end
		chip.arrow.Visible = item.edge
		if item.edge then
			local left = item.delta < 0
			chip.arrow.Text = if left then "◀" else "▶"
			chip.arrow.TextColor3 = marker.color
			chip.arrow.Position = UDim2.new(if left then 0 else 1, if left then -7 else 7, 0.5, 0)
		end
	end
	for id, chip in chips do
		if not seen[id] then
			chip.frame.Visible = false
		end
	end
end

-- Așezarea busolei (HudController, la fiecare schimbare de ecran)
function CompassBar.place(rect: { x: number, y: number, w: number, h: number })
	if not (root :: Frame?) then
		return
	end
	root.AnchorPoint = Vector2.zero
	root.Position = UDim2.fromOffset(rect.x, rect.y)
	root.Size = UDim2.fromOffset(rect.w, rect.h)
end

-- Pentru playtest
function CompassBar.debugState(): { [string]: any }
	local shown = {}
	for id, chip in chips do
		if chip.frame.Visible then
			table.insert(shown, id)
		end
	end
	table.sort(shown)
	return {
		visible = (root :: Frame?) ~= nil and root.Visible,
		heading = smoothHeading,
		markers = shown,
		size = if root :: Frame? then { root.AbsoluteSize.X, root.AbsoluteSize.Y } else nil,
	}
end

function CompassBar.start()
	build()
	task.spawn(function()
		while true do
			markers = MapMarkers.list()
			-- semnele dispărute de tot (prieten plecat) se șterg
			local alive: { [string]: boolean } = {}
			for _, marker in markers do
				alive[marker.id] = true
			end
			for id, chip in chips do
				if not alive[id] then
					chip.frame:Destroy()
					chips[id] = nil
				end
			end
			task.wait(0.25)
		end
	end)
	RunService.RenderStepped:Connect(update)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.M then
			VillageMap.toggle()
		end
	end)
end

return CompassBar
