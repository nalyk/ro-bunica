--!strict
-- Ecranul de încărcare: o scenă scurtă de desen animat cât se încarcă jocul.
-- Satul la apus (zoom lent), benzi de cusătură care curg sus și jos, logo-ul care cade cu turtire și
-- lucire, Bunica ce răsare din colț și, în buclă, Hoțomanul care se furișează și ia papucul („PLEOSC!”).
-- Jos, bara de progres se „coase” cu papucul pe vârf; deasupra, sfaturi. La final, două perdele brodate
-- se închid și se deschid peste joc. Respectă „Reduced Motion” (fără tremur, blitz sau rotiri).
-- Stă în ReplicatedFirst, deci nu folosește nimic din ReplicatedStorage până nu e încărcat jocul.

local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Assets = require(script.Parent.LoadingAssets)

local LoadingScreen = {}

local INK = Color3.fromRGB(58, 34, 24)
local PAPER = Color3.fromRGB(250, 241, 222)
local RED = Color3.fromRGB(215, 38, 61)
local GOLD = Color3.fromRGB(255, 205, 70)
local FONT = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold)
local MIN_SECONDS = 4.5 -- prima scenă (logo, Bunica, prima aruncare) se vede mereu întreagă
local MAX_SECONDS = 40 -- după atât, jocul pornește oricum
local CYCLE = 6 -- o scenă hoț → papuc → PLEOSC

local TIPS = {
	ro = {
		"Ascunde în beci creaturile scumpe înainte de noapte.",
		"Noaptea, ține apăsat pe creatura unui vecin ca s-o furi.",
		"Hoțul lovit cu papucul scapă creatura.",
		"Trei jucători la horă cheamă Culesul de aur.",
		"Cu 50 de Nervi arunci făcălețul.",
		"Prietenii de pe server sunt familie: nu-și fură între ei.",
	},
	en = {
		"Hide your priciest creatures in the cellar before night.",
		"At night, hold on a neighbour's creature to steal it.",
		"A thief hit by the slipper drops the creature.",
		"Three players dancing the hora call the Golden Harvest.",
		"With 50 Nerves you can throw the rolling pin.",
		"Friends on the server are family: they never steal from each other.",
	},
}
local WORDS = {
	ro = { loading = "Se încarcă satul…", ready = "Gata!", pleosc = "PLEOSC!" },
	en = { loading = "Loading the village…", ready = "Ready!", pleosc = "PLEOSC!" },
}

export type Options = {
	-- demonstrație (playtest): progres simulat pe `demoSeconds`, fără să aștepte jocul
	demo: boolean?,
	demoSeconds: number?,
}

export type Handle = { finished: () -> boolean, progress: () -> number, stage: () -> string }

local function reducedMotion(): boolean
	local ok, value = pcall(function()
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and value == true
end

local function tween(
	instance: Instance,
	seconds: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local t = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

-- Un sunet din atlasul audio al jocului (regiune), fără să depindă de controllerele jocului
local function sound(region: string, volume: number, looped: boolean?): Sound?
	local r = Assets.regions[region]
	if not r then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = Assets.audio
	s.Volume = volume
	s.PlaybackRegionsEnabled = true
	s.PlaybackRegion = NumberRange.new(r.start, r.start + r.length)
	s.LoopRegion = NumberRange.new(r.start, r.start + r.length)
	s.Looped = looped == true
	s.Parent = SoundService
	s:Play()
	if not looped then
		task.delay(r.length + 0.2, function()
			s:Destroy()
		end)
	end
	return s
end

local function image(name: string, props: { [string]: any }): ImageLabel
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.Image = Assets[name].image
	for key, value in props do
		(label :: any)[key] = value
	end
	return label
end

local function corner(parent: Instance, scale: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale, 0)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
end

local function text(props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = FONT
	label.TextScaled = true
	label.TextColor3 = PAPER
	for key, value in props do
		(label :: any)[key] = value
	end
	return label
end

-- Stările CoreGui pe care le ascundem cât ține ecranul (lista de jucători, chatul...) și le refacem exact
local function hideCoreGui(): () -> ()
	local saved: { [Enum.CoreGuiType]: boolean } = {}
	for _, kind in Enum.CoreGuiType:GetEnumItems() do
		if kind ~= Enum.CoreGuiType.All then
			local ok, enabled = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, kind)
			if ok then
				saved[kind] = enabled
			end
		end
	end
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
	return function()
		for kind, enabled in saved do
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, kind, enabled)
		end
	end
end

-- Progresul real: jocul încărcat (20 %), modelele sculptate trimise de server (60 %), personajul și
-- imaginile ecranului (20 %)
local function realProgress(): (number, boolean)
	local p = if game:IsLoaded() then 0.2 else 0
	local art = ReplicatedStorage:FindFirstChild("ArtTemplates")
	local expected = art and art:GetAttribute("Expected")
	local artDone = false
	if art and type(expected) == "number" and expected > 0 then
		local fraction = math.min(#art:GetChildren() / expected, 1)
		artDone = art:GetAttribute("Ready") == true or fraction >= 1
		p += 0.6 * (if artDone then 1 else fraction)
	end
	local character = Players.LocalPlayer.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		p += 0.2
	end
	return math.min(p, 1), p >= 0.999 and artDone
end

function LoadingScreen.play(options: Options?): Handle
	local opts: Options = options or {}
	local reduced = reducedMotion()
	local language = if string.sub(string.lower(LocalizationService.RobloxLocaleId), 1, 2) == "ro"
		then "ro"
		else "en"
	local words = WORDS[language]
	local tips = TIPS[language]
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local restoreCore: () -> () = hideCoreGui()

	local gui = Instance.new("ScreenGui")
	gui.Name = "BunicaLoading"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- scena (tremură la impact) și perdelele (deasupra, pentru tranziția finală)
	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.Size = UDim2.fromScale(1, 1)
	stage.BackgroundColor3 = INK
	stage.BorderSizePixel = 0
	stage.ClipsDescendants = true
	stage.Parent = gui

	local bg = image("bg", {
		Name = "Background",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.16, 1.16),
		ScaleType = Enum.ScaleType.Crop,
		ImageTransparency = 1,
		Parent = stage,
	})
	-- lumina caldă de apus și umbra de cinema sus și jos
	local vignette = Instance.new("Frame")
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundColor3 = Color3.fromRGB(40, 18, 10)
	vignette.BorderSizePixel = 0
	vignette.ZIndex = 2
	vignette.Parent = stage
	local vg = Instance.new("UIGradient")
	vg.Rotation = 90
	vg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.25, 0.85),
		NumberSequenceKeypoint.new(0.6, 0.9),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	vg.Parent = vignette

	-- benzile de cusătură: sus și jos, curg în sensuri opuse (dale repetate, mutate cu o dală)
	local bands: { { frame: ImageLabel, dir: number } } = {}
	local function band(top: boolean)
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.ClipsDescendants = true
		holder.AnchorPoint = Vector2.new(0, if top then 0 else 1)
		holder.Position = UDim2.fromScale(if top then -1 else 1, if top then 0 else 1)
		holder.Size = UDim2.fromScale(1, 0.075)
		holder.ZIndex = 5
		holder.Parent = stage
		local strip = image("stitch", {
			ScaleType = Enum.ScaleType.Tile,
			Size = UDim2.new(1, 600, 1, 0),
			ZIndex = 5,
			Parent = holder,
		})
		local edge = Instance.new("Frame")
		edge.BackgroundColor3 = INK
		edge.BorderSizePixel = 0
		edge.AnchorPoint = Vector2.new(0, if top then 0 else 1)
		edge.Position = UDim2.fromScale(0, if top then 1 else 0)
		edge.Size = UDim2.new(1, 0, 0, 3)
		edge.ZIndex = 6
		edge.Parent = holder
		table.insert(bands, { frame = strip, dir = if top then -1 else 1 })
		return holder
	end
	local topBand = band(true)
	local bottomBand = band(false)

	-- personajele: înălțimea e o fracțiune din ecran, lățimea din proporția imaginii
	local function character(name: string, heightScale: number, anchor: Vector2, position: UDim2): ImageLabel
		local data = Assets[name]
		local label = image(name, {
			Name = name,
			AnchorPoint = anchor,
			Position = position,
			Size = UDim2.fromScale(heightScale * data.size.X / data.size.Y, heightScale),
			ZIndex = 3,
			Parent = stage,
		})
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectRatio = data.size.X / data.size.Y
		aspect.DominantAxis = Enum.DominantAxis.Height
		aspect.Parent = label
		return label
	end
	local bunicaHome = UDim2.fromScale(0.985, 1.02)
	local bunica = character("bunica", 0.72, Vector2.new(1, 1), UDim2.fromScale(0.985, 1.7))
	local thief = character("hotoman", 0.6, Vector2.new(0.5, 1), UDim2.fromScale(-0.3, 0.98))
	thief.ZIndex = 4

	-- logo-ul (cu o copie albă pentru lucire)
	local logoData = Assets[if language == "ro" then "logo_ro" else "logo_en"]
	local logo = Instance.new("ImageLabel")
	logo.Name = "Logo"
	logo.BackgroundTransparency = 1
	logo.Image = logoData.image
	logo.AnchorPoint = Vector2.new(0.5, 0.5)
	logo.Position = UDim2.fromScale(0.5, -0.4)
	logo.Size = UDim2.fromScale(0.5, 0.5)
	logo.ZIndex = 7
	logo.Parent = stage
	local logoAspect = Instance.new("UIAspectRatioConstraint")
	logoAspect.AspectRatio = logoData.size.X / logoData.size.Y
	logoAspect.Parent = logo
	local logoScale = Instance.new("UIScale")
	logoScale.Parent = logo
	local shine = logo:Clone()
	shine.Name = "Shine"
	shine.Position = UDim2.fromScale(0.5, 0.5)
	shine.Size = UDim2.fromScale(1, 1)
	shine.ImageColor3 = Color3.new(1, 1, 1)
	shine.ZIndex = 8
	for _, child in shine:GetChildren() do
		child:Destroy()
	end
	shine.Parent = logo
	local shineGradient = Instance.new("UIGradient")
	shineGradient.Rotation = 20
	shineGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.45, 1),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(0.55, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	shineGradient.Offset = Vector2.new(-1, 0)
	shineGradient.Parent = shine

	-- progresul: o bandă de cusătură care se „coase” de la stânga, cu papucul pe vârf
	local bar = Instance.new("Frame")
	bar.Name = "Progress"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.fromScale(0.5, 0.885)
	bar.Size = UDim2.fromScale(0.36, 0.035)
	bar.BackgroundColor3 = Color3.fromRGB(70, 40, 28)
	bar.BackgroundTransparency = 0.2
	bar.ZIndex = 9
	bar.Parent = stage
	corner(bar, 0.5)
	stroke(bar, PAPER, 2)
	local fill = Instance.new("Frame")
	fill.BackgroundTransparency = 1
	fill.ClipsDescendants = true
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 10
	fill.Parent = bar
	corner(fill, 0.5)
	local fillStrip = image("stitch", {
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(0, 2000, 1, 0),
		ZIndex = 10,
		Parent = fill,
	})
	local needle = image("slipper", {
		AnchorPoint = Vector2.new(0.5, 0.6),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(2.4, 2.4),
		ZIndex = 11,
		Parent = bar,
	})
	local needleAspect = Instance.new("UIAspectRatioConstraint")
	needleAspect.Parent = needle
	local percent = text({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 14, 0.5, 0),
		Size = UDim2.fromScale(0.22, 1.6),
		Text = "0%",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 9,
		Parent = bar,
	})
	stroke(percent, INK, 2)
	local status = text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.835),
		Size = UDim2.fromScale(0.7, 0.04),
		Text = words.loading,
		ZIndex = 9,
		Parent = stage,
	})
	stroke(status, INK, 2.5)
	local tip = text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.79),
		Size = UDim2.fromScale(0.62, 0.032),
		Text = tips[math.random(#tips)],
		TextColor3 = Color3.fromRGB(255, 232, 190),
		TextTransparency = 1,
		ZIndex = 9,
		Parent = stage,
	})
	stroke(tip, INK, 2)
	local tipStroke = tip:FindFirstChildOfClass("UIStroke") :: UIStroke
	tipStroke.Transparency = 1

	-- logo-ul stă în stânga-sus (Bunica ocupă dreapta); pe telefon în portret, centrat și mai lat
	local stageName = "intro" -- intro → loop → outro → done
	local logoHome = UDim2.fromScale(0.36, 0.25)
	local function layout()
		local camera = workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local portrait = viewport.Y > viewport.X
		logoHome = if portrait then UDim2.fromScale(0.5, 0.2) else UDim2.fromScale(0.36, 0.25)
		logo.Size = UDim2.fromScale(if portrait then 0.92 else 0.48, if portrait then 0.3 else 0.5)
		if stageName ~= "intro" then
			logo.Position = logoHome
		end
		bar.Size = UDim2.fromScale(if portrait then 0.62 else 0.36, if portrait then 0.024 else 0.035)
		tip.Size = UDim2.fromScale(if portrait then 0.9 else 0.62, 0.032)
	end
	layout()
	local layoutConnection = workspace.CurrentCamera
		and workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)

	-- efecte la impact
	local function shake(seconds: number, strength: number)
		if reduced then
			return
		end
		local untilTime = os.clock() + seconds
		task.spawn(function()
			while os.clock() < untilTime and stage.Parent do
				local k = (untilTime - os.clock()) / seconds
				stage.Position = UDim2.fromOffset(
					(math.random() - 0.5) * strength * k,
					(math.random() - 0.5) * strength * k
				)
				task.wait()
			end
			stage.Position = UDim2.new()
		end)
	end
	local function flash()
		if reduced then
			return
		end
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BackgroundTransparency = 0.45
		f.ZIndex = 20
		f.Parent = stage
		tween(f, 0.18, { BackgroundTransparency = 1 })
		task.delay(0.2, function()
			f:Destroy()
		end)
	end
	-- inel de praf care se lărgește și se stinge
	local function ring(position: UDim2, size: number, color: Color3)
		local r = Instance.new("Frame")
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		r.Position = position
		r.Size = UDim2.fromScale(size * 0.3, size * 0.3)
		r.BackgroundTransparency = 1
		r.ZIndex = 6
		r.Parent = stage
		corner(r, 0.5)
		local s = Instance.new("UIStroke")
		s.Color = color
		s.Thickness = 10
		s.Parent = r
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.Parent = r
		tween(r, 0.5, { Size = UDim2.fromScale(size, size) })
		tween(s, 0.5, { Thickness = 0, Transparency = 1 })
		task.delay(0.55, function()
			r:Destroy()
		end)
	end
	-- „PLEOSC!” pe o stea de benzi desenate
	local function burst(position: UDim2)
		local holder = Instance.new("Frame")
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = position
		holder.Size = UDim2.fromScale(0.26, 0.26)
		holder.BackgroundTransparency = 1
		holder.ZIndex = 12
		holder.Parent = stage
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.Parent = holder
		local scale = Instance.new("UIScale")
		scale.Scale = 0.2
		scale.Parent = holder
		for i = 0, 3 do -- patru pătrate rotite = stea cu 16 colțuri
			local ray = Instance.new("Frame")
			ray.AnchorPoint = Vector2.new(0.5, 0.5)
			ray.Position = UDim2.fromScale(0.5, 0.5)
			ray.Size = UDim2.fromScale(0.72, 0.72)
			ray.Rotation = i * 22.5
			ray.BackgroundColor3 = GOLD
			ray.ZIndex = 12
			ray.Parent = holder
			stroke(ray, INK, 4)
		end
		local label = text({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.1, 0.42),
			Text = words.pleosc,
			TextColor3 = RED,
			Rotation = -8,
			ZIndex = 13,
			Parent = holder,
		})
		stroke(label, PAPER, 4)
		tween(scale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
		task.delay(0.75, function()
			tween(scale, 0.18, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		end)
		task.delay(1, function()
			holder:Destroy()
		end)
	end

	-- papucul aruncat: arc (Bézier pătratic) de la mâna Bunicii la capul hoțului, rotindu-se
	local function throwSlipper(onHit: () -> ())
		local from = bunica.AbsolutePosition + bunica.AbsoluteSize * Vector2.new(0.78, 0.06)
		local to = thief.AbsolutePosition + thief.AbsoluteSize * Vector2.new(0.68, 0.12)
		local control = (from + to) / 2 - Vector2.new(0, stage.AbsoluteSize.Y * 0.32)
		local s = image("slipper", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(0.09, 0.09),
			ZIndex = 11,
			Parent = stage,
		})
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.Parent = s
		sound("sfx.whoosh", 0.7)
		local duration = 0.55
		local start = os.clock()
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			local t = math.min((os.clock() - start) / duration, 1)
			local p = (1 - t) ^ 2 * from + 2 * (1 - t) * t * control + t ^ 2 * to
			local origin = stage.AbsolutePosition
			s.Position = UDim2.fromOffset(p.X - origin.X, p.Y - origin.Y)
			s.Rotation = if reduced then 0 else t * 760
			if t >= 1 then
				connection:Disconnect()
				s:Destroy()
				onHit()
			end
		end)
	end

	-- o scenă: hoțul se furișează, Bunica aruncă, PLEOSC, hoțul zboară din cadru
	local thiefState = "out"
	local function scene()
		thiefState = "sneak"
		thief.Rotation = 0
		thief.Position = UDim2.fromScale(-0.3, 0.98)
		tween(thief, 2.3, { Position = UDim2.fromScale(0.3, 0.98) }, Enum.EasingStyle.Linear)
		task.wait(2.3)
		if not gui.Parent then
			return
		end
		thiefState = "idle"
		-- avântul Bunicii
		tween(bunica, 0.22, { Rotation = 6 })
		task.wait(0.22)
		tween(bunica, 0.16, { Rotation = -5 }, Enum.EasingStyle.Back)
		throwSlipper(function()
			sound("sfx.pleosc", 0.9)
			local head = thief.AbsolutePosition
				+ thief.AbsoluteSize * Vector2.new(0.6, 0.15)
				- stage.AbsolutePosition
			local at = UDim2.fromOffset(head.X, head.Y)
			burst(at)
			ring(at, 0.3, PAPER)
			flash()
			shake(0.3, 18)
			thiefState = "flying"
			-- hoțul zboară în sus și în afara cadrului, dându-se peste cap
			tween(
				thief,
				0.9,
				{ Position = UDim2.fromScale(-0.25, 0.35) },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
			if not reduced then
				tween(thief, 0.9, { Rotation = -540 }, Enum.EasingStyle.Linear)
			end
			-- Bunica țopăie de bucurie
			tween(bunica, 0.15, { Rotation = 0 })
			tween(bunica, 0.18, { Position = bunicaHome - UDim2.fromScale(0, 0.05) }, Enum.EasingStyle.Quad)
			task.delay(0.18, function()
				tween(bunica, 0.3, { Position = bunicaHome }, Enum.EasingStyle.Bounce)
			end)
		end)
	end

	-- starea comună a buclei
	local started = os.clock()
	local shown = 0 -- progresul afișat (netezit)
	local target = 0
	local ready = false
	local finished = false
	local music = sound("music.zi", 0, true)
	if music then
		tween(music, 1.5, { Volume = 0.32 })
	end

	local step = RunService.RenderStepped:Connect(function(dt: number)
		local t = os.clock() - started
		-- zoom lent pe fundal
		bg.Size = UDim2.fromScale(1.16 - math.min(t / 20, 1) * 0.08, 1.16 - math.min(t / 20, 1) * 0.08)
		-- benzile curg
		for _, b in bands do
			local width = b.frame.AbsoluteSize.Y * Assets.stitch.size.X / Assets.stitch.size.Y
			b.frame.TileSize = UDim2.fromOffset(width, b.frame.AbsoluteSize.Y)
			if width > 0 then
				local x = (t * 40 * b.dir) % width
				b.frame.Position = UDim2.fromOffset(-x, 0)
			end
		end
		-- respirația logo-ului
		if not reduced and stageName ~= "intro" then
			logoScale.Scale = 1 + math.sin(t * 2.2) * 0.012
		end
		-- pasul de hoț: săltat pe vârfuri și legănat
		if thiefState == "sneak" then
			local stepPhase = t * 7
			thief.Rotation = if reduced then 0 else math.sin(stepPhase) * 4
			thief.AnchorPoint = Vector2.new(0.5, 1 + math.abs(math.sin(stepPhase)) * 0.035)
		elseif thiefState ~= "flying" then
			thief.AnchorPoint = Vector2.new(0.5, 1)
		end
		-- bara: netezită, cu dungile cusăturii care curg
		shown += (target - shown) * math.min(1, dt * 5)
		fill.Size = UDim2.fromScale(shown, 1)
		needle.Position = UDim2.fromScale(shown, 0.5)
		needle.Rotation = if reduced then 0 else math.sin(t * 9) * 10
		fillStrip.Position = UDim2.fromOffset(-((t * 30) % math.max(1, fill.AbsoluteSize.Y * 4)), 0)
		percent.Text = string.format("%d%%", math.floor(shown * 100 + 0.5))
	end)

	-- intrarea: fundalul, benzile, logo-ul, Bunica
	task.spawn(function()
		tween(bg, 0.9, { ImageTransparency = 0 })
		tween(topBand, 0.6, { Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Quart)
		tween(bottomBand, 0.6, { Position = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Quart)
		task.wait(0.4)
		-- logo-ul cade și se turtește la aterizare
		logoScale.Scale = 1.25
		tween(logo, 0.42, { Position = logoHome }, Enum.EasingStyle.Back)
		tween(logoScale, 0.42, { Scale = 1 }, Enum.EasingStyle.Back)
		task.wait(0.36)
		sound("sfx.pleosc", 0.55)
		ring(logoHome, 0.55, Color3.fromRGB(255, 236, 200))
		shake(0.2, 10)
		if not reduced then
			logo.Rotation = -3
			tween(logo, 0.5, { Rotation = 0 }, Enum.EasingStyle.Elastic)
		end
		stageName = "loop"
		tween(shineGradient, 0.9, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine)
		task.wait(0.15)
		tween(bunica, 0.6, { Position = bunicaHome }, Enum.EasingStyle.Back)
		tween(tip, 0.4, { TextTransparency = 0 })
		tween(tipStroke, 0.4, { Transparency = 0 })
		task.wait(0.3)
		-- bucla de scene până la final
		while gui.Parent and not finished do
			local cycleStart = os.clock()
			scene()
			-- lucirea pe logo, o dată pe scenă
			shineGradient.Offset = Vector2.new(-1, 0)
			tween(shineGradient, 0.9, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine)
			while os.clock() - cycleStart < CYCLE and gui.Parent and not finished do
				task.wait(0.1)
			end
		end
	end)

	-- sfaturile se schimbă
	task.spawn(function()
		local index = math.random(#tips)
		while gui.Parent and not finished do
			task.wait(3.6)
			if finished or not gui.Parent then
				break
			end
			tween(tip, 0.25, { TextTransparency = 1 })
			tween(tipStroke, 0.25, { Transparency = 1 })
			task.wait(0.25)
			index = index % #tips + 1
			tip.Text = tips[index]
			tween(tip, 0.25, { TextTransparency = 0 })
			tween(tipStroke, 0.25, { Transparency = 0 })
		end
	end)

	-- perdelele brodate: se închid peste scenă, apoi se deschid peste joc
	local function curtains(close: boolean, seconds: number): { Frame }
		local panels = {}
		for i, side in { -1, 1 } do
			local panel = Instance.new("Frame")
			panel.Name = "Curtain" .. i
			panel.BackgroundColor3 = PAPER
			panel.BorderSizePixel = 0
			panel.AnchorPoint = Vector2.new(if side < 0 then 1 else 0, 0)
			panel.Size = UDim2.fromScale(0.5, 1)
			panel.ZIndex = 30
			panel.Position = UDim2.fromScale(if close then (if side < 0 then 0 else 1) else 0.5, 0)
			panel.Parent = gui
			-- trei benzi de cusătură pe perdea și marginea de cerneală spre mijloc
			for _, y in { 0.12, 0.5, 0.88 } do
				local strip = image("stitch", {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0, y),
					Size = UDim2.fromScale(1, 0.09),
					ScaleType = Enum.ScaleType.Tile,
					TileSize = UDim2.fromScale(0.42, 1),
					ZIndex = 31,
					Parent = panel,
				})
				strip.Name = "Band"
			end
			local edge = Instance.new("Frame")
			edge.BackgroundColor3 = RED
			edge.BorderSizePixel = 0
			edge.AnchorPoint = Vector2.new(if side < 0 then 1 else 0, 0)
			edge.Position = UDim2.fromScale(if side < 0 then 1 else 0, 0)
			edge.Size = UDim2.new(0, 8, 1, 0)
			edge.ZIndex = 32
			edge.Parent = panel
			table.insert(panels, panel)
			local goal = if close
				then UDim2.fromScale(0.5, 0)
				else UDim2.fromScale(if side < 0 then 0 else 1, 0)
			if not close then
				panel.Position = UDim2.fromScale(0.5, 0)
			end
			tween(
				panel,
				seconds,
				{ Position = goal },
				if close then Enum.EasingStyle.Quad else Enum.EasingStyle.Quint,
				if close then Enum.EasingDirection.In else Enum.EasingDirection.Out
			)
		end
		return panels
	end

	local function finish()
		if finished then
			return
		end
		finished = true
		stageName = "outro"
		target = 1
		status.Text = words.ready
		sound("sfx.reward1", 0.5)
		task.wait(0.5)
		local closing = curtains(true, 0.38)
		task.wait(0.42)
		sound("sfx.open", 0.7)
		stage.Visible = false
		restoreCore()
		if music then
			tween(music, 1.2, { Volume = 0 })
			task.delay(1.3, function()
				(music :: Sound):Destroy()
			end)
		end
		for _, panel in closing do
			panel:Destroy()
		end
		task.wait(0.15)
		curtains(false, 0.7)
		task.wait(0.75)
		step:Disconnect()
		if layoutConnection then
			layoutConnection:Disconnect()
		end
		gui:Destroy()
		stageName = "done"
	end

	-- progresul: real (jocul, modelele, personajul) sau simulat în demonstrație
	task.spawn(function()
		local imagesLoaded = false
		task.spawn(function()
			-- imaginile scenei întâi (ca să nu apară goale), apoi iconițele și sunetul jocului
			local list = { bg, bunica, thief, logo, needle }
			pcall(function()
				ContentProvider:PreloadAsync(list)
			end)
			imagesLoaded = true
		end)
		while not finished do
			local elapsed = os.clock() - started
			if opts.demo then
				local seconds = opts.demoSeconds or 8
				target = math.min(elapsed / seconds, 1)
				ready = elapsed >= seconds
			else
				local p, done = realProgress()
				target = math.max(target, p)
				ready = done and imagesLoaded
			end
			if (ready and elapsed >= MIN_SECONDS) or elapsed >= MAX_SECONDS then
				finish()
				break
			end
			task.wait(0.1)
		end
	end)

	return {
		finished = function()
			return stageName == "done"
		end,
		progress = function()
			return shown
		end,
		stage = function()
			return stageName
		end,
	}
end

return LoadingScreen
