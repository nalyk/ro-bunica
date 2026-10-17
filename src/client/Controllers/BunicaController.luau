--!strict
-- Bunica pe client: fața desenată (ochelari rotunzi, sprâncene, gură), animații procedurale pe articulații
-- și bula de dialog. Pozele se aplică local pe C0 (modificările de pe client nu se replică), deci nu costă rețea.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Typography = require(Shared.Visual.Typography)
local BunicaLines = require(Shared.Config.BunicaLines)
local Sounds = require(Shared.Config.Sounds)
local ClientState = require(script.Parent.ClientState)
local Sfx = require(script.Parent.Sfx)
local Music = require(script.Parent.Music)
local Net = require(Shared.Net)
local Joints = require(script.Parent.Joints)

local BunicaController = {}

type Face = {
	browLeft: Frame,
	browRight: Frame,
	mouth: Frame,
	mouthCorner: UICorner,
	pupils: { Frame },
	lids: { Frame },
}

type Rig = {
	model: Model,
	joints: { [string]: Joints.Joint }, -- Motor6D sau AnimationConstraint, prin Joints
	missing: number, -- articulații încă nesosite (StreamingEnabled)
	current: { [string]: CFrame }, -- poza curentă, pentru tranziții moi
	face: Face?,
	throwUntil: number,
	phase: number,
}

local rigs: { [Model]: Rig } = {}

local INK = Color3.fromRGB(40, 25, 20)
local JOINTS = {
	"Root",
	"Waist",
	"Neck",
	"RightShoulder",
	"LeftShoulder",
	"RightElbow",
	"LeftElbow",
	"RightHip",
	"LeftHip",
	"RightKnee",
	"LeftKnee",
}

-- Fața ---------------------------------------------------------------------------

local function circle(parent: Instance, size: UDim2, position: UDim2, color: Color3, stroke: number?): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame
	if stroke then
		local line = Instance.new("UIStroke")
		line.Thickness = stroke
		line.Color = INK
		line.Parent = frame
	end
	frame.Parent = parent
	return frame
end

local function bar(parent: Instance, size: UDim2, position: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = INK
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame
	frame.Parent = parent
	return frame
end

local function buildFace(head: BasePart): Face
	for _, child in head:GetChildren() do
		if child:IsA("Decal") then
			child.Transparency = 1 -- fața implicită Roblox, înlocuită de cea desenată
		end
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BunicaFace"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(200, 200)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.LightInfluence = 0.5
	gui.Parent = head

	local pupils, lids = {}, {}
	for _, x in { 0.32, 0.68 } do
		-- ochelari rotunzi, ochiul alb, pupila și pleoapa (pentru somn)
		local lens = circle(gui, UDim2.fromScale(0.3, 0.3), UDim2.fromScale(x, 0.42), Color3.new(1, 1, 1), 5)
		local pupil = circle(lens, UDim2.fromScale(0.36, 0.36), UDim2.fromScale(0.5, 0.55), INK)
		local lid = Instance.new("Frame")
		lid.Size = UDim2.fromScale(1, 0)
		lid.BackgroundColor3 = Color3.fromRGB(230, 185, 155)
		lid.BorderSizePixel = 0
		lid.ZIndex = 3
		lid.Parent = lens
		table.insert(pupils, pupil)
		table.insert(lids, lid)
	end
	bar(gui, UDim2.fromScale(0.08, 0.025), UDim2.fromScale(0.5, 0.42)) -- puntea ochelarilor
	local browLeft = bar(gui, UDim2.fromScale(0.22, 0.04), UDim2.fromScale(0.32, 0.22))
	local browRight = bar(gui, UDim2.fromScale(0.22, 0.04), UDim2.fromScale(0.68, 0.22))
	-- obrajii rumeni
	circle(gui, UDim2.fromScale(0.14, 0.09), UDim2.fromScale(0.18, 0.66), Color3.fromRGB(240, 140, 140))
	circle(gui, UDim2.fromScale(0.14, 0.09), UDim2.fromScale(0.82, 0.66), Color3.fromRGB(240, 140, 140))
	local mouth = Instance.new("Frame")
	mouth.AnchorPoint = Vector2.new(0.5, 0.5)
	mouth.Position = UDim2.fromScale(0.5, 0.76)
	mouth.BackgroundColor3 = Color3.fromRGB(120, 30, 40)
	mouth.BorderSizePixel = 0
	local mouthCorner = Instance.new("UICorner")
	mouthCorner.Parent = mouth
	mouth.Parent = gui
	return {
		browLeft = browLeft,
		browRight = browRight,
		mouth = mouth,
		mouthCorner = mouthCorner,
		pupils = pupils,
		lids = lids,
	}
end

-- Expresii: sprâncene (unghi, înălțime), gură (lățime, înălțime, rotunjire), pleoape (0 = deschis)
local EXPRESSIONS: { [string]: { brow: number, browY: number, mouthW: number, mouthH: number, round: number, lid: number } } =
	{
		Sleeping = { brow = 0, browY = 0.25, mouthW = 0.18, mouthH = 0.03, round = 1, lid = 1 },
		Suspicious = { brow = 12, browY = 0.24, mouthW = 0.2, mouthH = 0.04, round = 0.2, lid = 0.45 },
		Watching = { brow = 0, browY = 0.22, mouthW = 0.24, mouthH = 0.06, round = 1, lid = 0 },
		Awake = { brow = 25, browY = 0.26, mouthW = 0.2, mouthH = 0.14, round = 1, lid = 0 },
		Rage = { brow = 35, browY = 0.28, mouthW = 0.34, mouthH = 0.12, round = 0.3, lid = 0.15 },
		Celebrate = { brow = -15, browY = 0.18, mouthW = 0.38, mouthH = 0.16, round = 1, lid = 0 },
	}

local function applyExpression(face: Face, mood: string)
	local e = EXPRESSIONS[mood] or EXPRESSIONS.Watching
	face.browLeft.Rotation = e.brow
	face.browRight.Rotation = -e.brow
	face.browLeft.Position = UDim2.fromScale(0.32, e.browY)
	face.browRight.Position = UDim2.fromScale(0.68, e.browY)
	face.mouth.Size = UDim2.fromScale(e.mouthW, e.mouthH)
	face.mouthCorner.CornerRadius = UDim.new(e.round, 0)
	for _, lid in face.lids do
		lid.Size = UDim2.fromScale(1, e.lid)
	end
end

-- Animații procedurale ---------------------------------------------------------------

local function rad(x: number): number
	return math.rad(x)
end

-- Poziția fiecărei articulații pentru o stare, la timpul t
local function pose(mood: string, t: number, throwing: boolean): { [string]: CFrame }
	local p: { [string]: CFrame } = {}
	if throwing then
		-- brațul drept trece rapid în față
		p.RightShoulder = CFrame.Angles(rad(70), 0, rad(-10))
		p.Waist = CFrame.Angles(0, rad(-25), 0)
		return p
	end
	if mood == "Sleeping" then
		local breath = math.sin(t * 1.6)
		p.Neck = CFrame.Angles(rad(-22 + breath * 3), 0, rad(8))
		p.Waist = CFrame.Angles(rad(-6 + breath * 2), 0, 0)
		p.RightShoulder = CFrame.Angles(rad(-10), 0, rad(15))
		p.LeftShoulder = CFrame.Angles(rad(-10), 0, rad(-15))
	elseif mood == "Suspicious" then
		-- mâna la frunte, privește în jur
		p.Neck = CFrame.Angles(rad(5), rad(math.sin(t * 1.3) * 35), 0)
		p.Waist = CFrame.Angles(rad(8), 0, 0)
		p.RightShoulder = CFrame.Angles(rad(150), 0, rad(-25))
		p.RightElbow = CFrame.Angles(rad(70), 0, 0)
	elseif mood == "Awake" then
		-- avântul: brațul drept sus, în spate
		p.RightShoulder = CFrame.Angles(rad(165), 0, rad(10))
		p.Waist = CFrame.Angles(0, rad(20), 0)
		p.Neck = CFrame.Angles(rad(-5), 0, 0)
	elseif mood == "Rage" then
		p.RightShoulder = CFrame.Angles(rad(math.sin(t * 18) * 80 + 60), 0, 0)
		p.LeftShoulder = CFrame.Angles(rad(math.cos(t * 18) * 80 + 60), 0, 0)
		p.Neck = CFrame.Angles(0, rad(math.sin(t * 20) * 15), 0)
	elseif mood == "Celebrate" then
		-- țopăie cu brațele sus
		local hop = math.abs(math.sin(t * 9)) * 1.2
		p.Root = CFrame.new(0, hop, 0)
		p.RightShoulder = CFrame.Angles(rad(170), 0, rad(math.sin(t * 9) * 20))
		p.LeftShoulder = CFrame.Angles(rad(170), 0, rad(-math.sin(t * 9) * 20))
		p.Neck = CFrame.Angles(rad(-15), 0, 0)
	else -- Watching: mâinile în șold
		p.RightShoulder = CFrame.Angles(0, 0, rad(40))
		p.LeftShoulder = CFrame.Angles(0, 0, rad(-40))
		p.RightElbow = CFrame.Angles(rad(80), 0, 0)
		p.LeftElbow = CFrame.Angles(rad(80), 0, 0)
		p.Neck = CFrame.Angles(0, rad(math.sin(t * 0.7) * 20), 0)
	end
	return p
end

-- Bula de dialog -----------------------------------------------------------------

local function showBubble(model: Model, key: string)
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local old = head:FindFirstChild("BunicaBubble")
	if old then
		old:Destroy()
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BunicaBubble"
	billboard.Size = UDim2.fromOffset(240, 70)
	billboard.StudsOffset = Vector3.new(0, 5.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 90
	billboard.Parent = head
	local bubble = Instance.new("Frame")
	bubble.Size = UDim2.fromScale(1, 0.8)
	bubble.BackgroundColor3 = Color3.fromRGB(255, 252, 240)
	bubble.BorderSizePixel = 0
	bubble.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.4, 0)
	corner.Parent = bubble
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(200, 30, 40)
	stroke.Parent = bubble
	local tail = Instance.new("Frame")
	tail.Size = UDim2.fromOffset(16, 16)
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position = UDim2.fromScale(0.5, 1)
	tail.Rotation = 45
	tail.BackgroundColor3 = bubble.BackgroundColor3
	tail.BorderSizePixel = 0
	tail.ZIndex = 0
	tail.Parent = bubble
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -16, 1, -8)
	label.Position = UDim2.fromOffset(8, 4)
	label.BackgroundTransparency = 1
	label.FontFace = Typography.body
	label.TextScaled = true
	label.TextColor3 = INK
	label.Text = ClientState.t(key)
	label.Parent = bubble
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = bubble
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	-- Vocea înregistrată (în limba jucătorului sau în română), lipită de cap ca să meargă cu Bunica;
	-- replica de dinainte se oprește. Fără înregistrare: un sunet scurt de caracter.
	local voices = BunicaLines.voice[ClientState.language()] or BunicaLines.voice[BunicaLines.voiceFallback]
	local voice = voices[key] or BunicaLines.voice[BunicaLines.voiceFallback][key]
	local previous = head:FindFirstChild("BunicaVoice")
	if previous then
		previous:Destroy()
	end
	if voice then
		local sound = Instance.new("Sound")
		sound.Name = "BunicaVoice"
		sound.SoundId = voice.id
		sound.Volume = BunicaLines.voiceVolume
		sound.RollOffMinDistance = 12
		sound.RollOffMaxDistance = 160
		sound.Parent = head
		sound:Play()
		Debris:AddItem(sound, voice.seconds + 1)
		-- muzica se dă la o parte cât vorbește o Bunica din apropiere
		local camera = Workspace.CurrentCamera
		if camera and (camera.CFrame.Position - head.Position).Magnitude < 80 then
			Music.duck(voice.seconds + 0.3)
		end
	elseif string.find(key, "bunica.hit", 1, true) then
		Sfx.play(Sounds.bunicaGiggle, head.Position, 0.8)
	end
	task.delay(math.max(BunicaLines.bubbleSeconds, if voice then voice.seconds + 0.4 else 0), function()
		billboard:Destroy()
	end)
end

-- Ciclul de viață --------------------------------------------------------------------

local function track(model: Model)
	if rigs[model] then
		return
	end
	local joints = {}
	local missing = Joints.collect(model, JOINTS, joints)
	local head = model:FindFirstChild("Head") :: BasePart?
	local rig: Rig = {
		model = model,
		joints = joints,
		current = {},
		missing = missing,
		-- Bunica sculptată are fața pictată în textură: fără fața desenată 2D
		face = if head and not model:GetAttribute("Sculpted") then buildFace(head) else nil,
		throwUntil = 0,
		phase = math.random() * 10,
	}
	rigs[model] = rig

	model:GetAttributeChangedSignal("LineSeq"):Connect(function()
		local key = model:GetAttribute("Line")
		if type(key) == "string" then
			showBubble(model, key)
		end
	end)
	model:GetAttributeChangedSignal("Windup"):Connect(function()
		if model:GetAttribute("Windup") == false then
			rig.throwUntil = os.clock() + 0.35
		end
	end)
	model:GetAttributeChangedSignal("State"):Connect(function()
		local head2 = model:FindFirstChild("Head") :: BasePart?
		if model:GetAttribute("State") == "Suspicious" and head2 then
			Sfx.play(Sounds.bunicaSneeze, head2.Position, 0.5) -- se trezește strănutând
		end
	end)
	model.Destroying:Connect(function()
		rigs[model] = nil
	end)
end

-- Cu StreamingEnabled, părțile modelului pot sosi după el: completăm articulațiile lipsă
local function refreshJoints(rig: Rig)
	rig.missing = Joints.collect(rig.model, JOINTS, rig.joints)
	if not rig.face and not rig.model:GetAttribute("Sculpted") then
		local head = rig.model:FindFirstChild("Head") :: BasePart?
		if head then
			rig.face = buildFace(head)
		end
	end
end

local function currentMood(model: Model): string
	local mood = model:GetAttribute("Mood")
	if type(mood) == "string" and mood ~= "" then
		return mood
	end
	local state = model:GetAttribute("State")
	return if type(state) == "string" then state else "Sleeping"
end

-- Bunica îl întâmpină pe jucător după ce se închide ecranul de încărcare (ReplicatedFirst/LoadingScreen)
local function greetAfterLoading()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	playerGui:WaitForChild("BunicaLoading", 3) -- ecranul poate apărea puțin după pornirea controllerelor
	local deadline = os.clock() + 60
	while playerGui:FindFirstChild("BunicaLoading") and os.clock() < deadline do
		task.wait(0.25)
	end
	Net.get("Greeted"):FireServer()
end

function BunicaController.start()
	task.spawn(greetAfterLoading)
	local village = Workspace:WaitForChild("Village")
	for _, descendant in village:GetDescendants() do
		if descendant:IsA("Model") and descendant.Name == "Bunica" then
			task.spawn(track, descendant)
		end
	end
	village.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("Model") and descendant.Name == "Bunica" then
			task.spawn(track, descendant :: Model)
		end
	end)

	local lastMoods: { [Model]: string } = {}
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for model, rig in rigs do
			local mood = currentMood(model)
			if rig.face and lastMoods[model] ~= mood then
				lastMoods[model] = mood
				applyExpression(rig.face, mood)
			end
			if rig.missing > 0 or not rig.face then
				refreshJoints(rig)
			end
			local throwing = t < rig.throwUntil
			local target =
				pose(if model:GetAttribute("Windup") == true then "Awake" else mood, t + rig.phase, throwing)
			for name, joint in rig.joints do
				local goal = target[name] or CFrame.identity
				-- tranziții moi între poze, aplicate peste cadrul de bază al articulației
				local blended = (rig.current[name] or CFrame.identity):Lerp(
					goal,
					if throwing then 0.6 else 0.2
				)
				rig.current[name] = blended
				joint.set(blended)
			end
		end
	end)
end

return BunicaController
