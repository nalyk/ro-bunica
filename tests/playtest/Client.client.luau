--!strict
-- Agentul de playtest de pe client: execută comenzile regizorului (serverul) pe căile unui jucător real
-- (mers cu fizică, prompt-uri apăsate, aceleași remote-uri ca UI-ul) și raportează ce vede clientul.

local Lighting = game:GetService("Lighting")
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local walkModule: any = ReplicatedStorage:WaitForChild("PlaytestShared"):WaitForChild("Walk")
local Walk = (require :: any)(walkModule)

local player = Players.LocalPlayer
local controllers = player:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("Controllers")
local ClientState = (require :: any)(controllers:WaitForChild("ClientState"))

local counters: { [string]: number } = { Alarm = 0, Knockback = 0, Hit = 0, Projectile = 0, Replay = 0 }
local tutorialStages: { string } = {}
local notifications: { string } = {}
local clientErrors: { string } = {}

Net.get("Tutorial").OnClientEvent:Connect(function(stage)
	table.insert(tutorialStages, stage)
end)
for _, name in { "Alarm", "Knockback", "Hit", "Projectile", "Replay" } do
	Net.get(name).OnClientEvent:Connect(function()
		counters[name] += 1
	end)
end
Net.get("Notify").OnClientEvent:Connect(function(key)
	table.insert(notifications, key)
end)
LogService.MessageOut:Connect(function(message, messageType)
	if messageType == Enum.MessageType.MessageError and not string.find(message, "PLAYTEST", 1, true) then
		table.insert(clientErrors, message)
	end
end)

local function character(): Model
	return player.Character or player.CharacterAdded:Wait()
end

local function findPrompt(name: string, ownerUserId: number?, near: Vector3): ProximityPrompt?
	local best, bestDistance = nil, math.huge
	for _, descendant in Workspace:GetDescendants() do
		if
			descendant:IsA("ProximityPrompt")
			and descendant.Name == name
			and (ownerUserId == nil or descendant:GetAttribute("OwnerUserId") == ownerUserId)
		then
			local parent = descendant.Parent
			if parent and parent:IsA("BasePart") then
				local distance = (parent.Position - near).Magnitude
				if distance < bestDistance then
					best, bestDistance = descendant, distance
				end
			end
		end
	end
	return best
end

local function hudTexts(): { string }
	local texts = {}
	local gui = player:WaitForChild("PlayerGui"):FindFirstChild("BunicaUI")
	if gui then
		for _, descendant in gui:GetDescendants() do
			if (descendant:IsA("TextLabel") or descendant:IsA("TextButton")) and descendant.Visible then
				table.insert(texts, descendant.Text)
			end
		end
	end
	return texts
end

local function countKeys(t: any): number
	local n = 0
	for _ in t or {} do
		n += 1
	end
	return n
end

local ops: { [string]: (...any) -> any } = {}

function ops.walkTo(target: Vector3, tolerance: number?): number
	return Walk.to(character(), target, tolerance)
end

-- Ține apăsat prompt-ul cel mai apropiat (exact ca un jucător care ține tasta/butonul).
function ops.holdPrompt(name: string, ownerUserId: number?, near: Vector3): string
	local prompt = findPrompt(name, ownerUserId, near)
	if not prompt then
		return "prompt negăsit"
	end
	if not prompt.Enabled then
		return "prompt dezactivat"
	end
	-- Implicit se arată doar prompt-ul cel mai apropiat (OnePerButton); cu pedestalele la 7 studs, agentul
	-- poate sta mai aproape de creatura vecină și atunci apăsarea nu ajunge la țintă. Local, doar în test.
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	task.wait(0.1)
	local triggered = false
	local shown = false
	local c1 = prompt.Triggered:Connect(function()
		triggered = true
	end)
	local c2 = prompt.PromptShown:Connect(function()
		shown = true
	end)
	prompt:InputHoldBegin()
	-- Progresul de „ține apăsat” avansează pe cadre; Studio pe CPU (fără GPU) poate rula la câteva fps,
	-- deci ținem apăsat până se declanșează efectiv (cu limită), nu un timp fix
	local deadline = os.clock() + prompt.HoldDuration + 12
	task.wait(prompt.HoldDuration)
	while not triggered and os.clock() < deadline do
		task.wait(0.1)
	end
	prompt:InputHoldEnd()
	task.wait(0.2)
	c1:Disconnect()
	c2:Disconnect()
	if triggered then
		return "ok" -- după furt, serverul mută creatura (și prompt-ul dispare)
	end
	local parent = prompt.Parent :: BasePart?
	local root = character():FindFirstChild("HumanoidRootPart") :: BasePart
	if parent then
		local distance = (parent.Position - root.Position).Magnitude
		return string.format(
			"nedeclanșat: distanță %.1f (max %.1f), activ %s, afișat %s, părinte %s la %.1f,%.1f,%.1f",
			distance,
			prompt.MaxActivationDistance,
			tostring(prompt.Enabled),
			tostring(shown),
			parent.Name,
			parent.Position.X,
			parent.Position.Y,
			parent.Position.Z
		)
	end
	return "nedeclanșat (prompt fără părinte)"
end

function ops.fire(remote: string, ...: any): boolean
	Net.get(remote):FireServer(...)
	return true
end

-- Aruncă papucul spre personajul cu numele dat (aceeași cerere ca un click pe ecran).
function ops.throwAt(targetName: string): string
	local model = Workspace:FindFirstChild(targetName, true)
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return "țintă negăsită"
	end
	Net.get("Throw"):FireServer(root.Position, "Slipper")
	return "ok"
end

-- Încarcă efectele sonore și întoarce cele care nu s-au putut încărca.
function ops.preloadSounds(): { string }
	local ContentProvider = game:GetService("ContentProvider")
	local Sounds = require(Shared.Config.Sounds)
	local sounds = {}
	for _, id in Sounds do
		local sound = Instance.new("Sound")
		sound.SoundId = id :: string
		table.insert(sounds, sound)
	end
	local failed = {}
	ContentProvider:PreloadAsync(sounds, function(contentId: string, status: Enum.AssetFetchStatus)
		if status ~= Enum.AssetFetchStatus.Success then
			table.insert(failed, contentId .. " " .. status.Name)
		end
	end)
	return failed
end

-- Ce tip au articulațiile numite RightShoulder (Motor6D sau AnimationConstraint)
function ops.jointInfo(plotIndex: number): { string }
	local result = {}
	local plot = Workspace:WaitForChild("Village"):FindFirstChild("Plot" .. plotIndex)
	local rig = plot and plot:FindFirstChild("Bunica")
	for _, model in { rig, character() } do
		if model then
			for _, descendant in model:GetDescendants() do
				if descendant.Name == "RightShoulder" then
					table.insert(result, model.Name .. ": " .. descendant.ClassName)
				end
			end
		end
	end

	return result
end

-- Fața și bula Bunicii din ograda dată (verificare vizuală)
function ops.bunicaVisuals(plotIndex: number): { [string]: any }
	local plot = Workspace:WaitForChild("Village"):FindFirstChild("Plot" .. plotIndex)
	local rig = plot and plot:FindFirstChild("Bunica")
	local head = rig and rig:FindFirstChild("Head")
	return {
		face = head ~= nil and head:FindFirstChild("BunicaFace") ~= nil,
		bubble = head ~= nil and head:FindFirstChild("BunicaBubble") ~= nil,
	}
end

-- Cadru fix de cameră spre un punct, pentru capturi (revine singur)
function ops.lookAt(target: Vector3, from: Vector3, seconds: number): boolean
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(from, target)
	task.delay(seconds, function()
		camera.CameraType = Enum.CameraType.Custom
	end)
	return true
end

function ops.openShop(): number
	local ShopPanel = (require :: any)(controllers:WaitForChild("ShopPanel"))
	ShopPanel.toggle()
	task.wait(0.5)
	local rows = 0
	local gui = player.PlayerGui:FindFirstChild("BunicaUI")
	for _, panel in (gui and gui:GetChildren() or {}) :: { Instance } do
		if panel.Name == "Panel" and (panel :: Frame).Visible then
			local scroll = panel:FindFirstChildOfClass("ScrollingFrame")
			for _, child in (scroll and scroll:GetChildren() or {}) :: { Instance } do
				if child:IsA("Frame") then
					rows += 1
				end
			end
		end
	end
	ShopPanel.toggle()
	return rows
end

function ops.query(): { [string]: any }
	local state = ClientState.state
	local humanoid = character():FindFirstChildOfClass("Humanoid")
	local plants = 0
	for _, child in Workspace:GetChildren() do
		if child.Name == "Plant" then
			plants += 1
		end
	end
	return {
		lei = state.lei,
		nervi = state.nervi,
		ammo = state.ammo,
		pedestals = countKeys(state.pedestals),
		cellar = countKeys(state.cellar),
		seeds = state.seeds,
		hud = hudTexts(),
		clock = Lighting.ClockTime,
		plants = plants,
		counters = table.clone(counters),
		notifications = table.clone(notifications),
		walkSpeed = humanoid and humanoid.WalkSpeed or 0,
		errors = table.clone(clientErrors),
		tutorial = table.clone(tutorialStages),
		shopStock = table.clone(ClientState.shopStock),
		papuci = (function()
			local stats = player:FindFirstChild("leaderstats")
			local value = stats and stats:FindFirstChild("Papuci") :: IntValue?
			return if value then value.Value else -1
		end)(),
		position = (character():FindFirstChild("HumanoidRootPart") :: BasePart).Position,
	}
end

-- Dirijorul muzical: starea straturilor (pentru verificarea sincronizării) și un efect de probă
function ops.music(): { [string]: any }
	local SoundService = game:GetService("SoundService")
	local folder = SoundService:FindFirstChild("BunicaAudio")
	local Music = (require :: any)(controllers:WaitForChild("Music"))
	local AudioAtlas = require(Shared.Config.AudioAtlas)
	local layers = {}
	if folder then
		for _, name in { "zi", "noapte", "pericol", "urmarire" } do
			local p = folder:FindFirstChild("Player_" .. name) :: AudioPlayer?
			local fader = folder:FindFirstChild("Fader_" .. name) :: AudioFader?
			if p then
				local region = AudioAtlas.regions["music." .. name]
				layers[name] = {
					ready = p.IsReady,
					playing = p.IsPlaying,
					offset = p.TimePosition - region.start,
					volume = if fader then fader.Volume else -1,
				}
			end
		end
	end
	return { enabled = Music.isEnabled(), mixer = SoundService:GetMixerTime(), layers = layers }
end

function ops.cue(name: string): { [string]: any }
	local SoundService = game:GetService("SoundService")
	local Music = (require :: any)(controllers:WaitForChild("Music"))
	local now = SoundService:GetMixerTime()
	local at = Music.cue(name)
	return { now = now, at = at }
end

-- Testul de font: fiecare candidat scrie diacritice românești și chirilice (pentru captură)
function ops.fontTest(seconds: number): boolean
	local fonts = {
		"FredokaOne",
		"LuckiestGuy",
		"Bangers",
		"Cartoon",
		"Nunito",
		"Montserrat",
		"BuilderSans",
		"Arimo",
		"Roboto",
		"SourceSans",
		"GothamSSm",
		"Fondamento",
		"PermanentMarker",
		"Kalam",
		"Sarpanch",
		"DenkOne",
	}
	local gui = Instance.new("ScreenGui")
	gui.Name = "FontTest"
	gui.DisplayOrder = 100
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(255, 244, 222)
	frame.Parent = gui
	local list = Instance.new("UIGridLayout")
	list.CellSize = UDim2.new(0.5, -6, 0, 34)
	list.CellPadding = UDim2.fromOffset(6, 4)
	list.Parent = frame
	for _, name in fonts do
		local ok, font = pcall(function()
			return (Enum.Font :: any)[name]
		end)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Color3.fromRGB(58, 34, 24)
		label.Text = name .. ": Bunica ș ț ă î â ȘȚ Бабушка ёЖ 128"
		if ok and font then
			label.Font = font
		else
			label.Text = name .. ": (lipsește)"
		end
		label.Parent = frame
	end
	gui.Parent = player.PlayerGui
	task.delay(seconds, function()
		gui:Destroy()
	end)
	return true
end

-- Proiectilele în zbor (EffectsController): modelul sculptat cu textura lui (SurfaceAppearance) pe fiecare piesă
function ops.projectiles(): { string }
	local found = {}
	for _, child in workspace:GetChildren() do
		if child.Name == "Projectile" and child:IsA("BasePart") then
			local meshes, textured = 0, 0
			for _, d in child:GetDescendants() do
				if d:IsA("MeshPart") then
					meshes += 1
					if d:FindFirstChildWhichIsA("SurfaceAppearance") then
						textured += 1
					end
				end
			end
			local model = child:FindFirstChildWhichIsA("Model")
			table.insert(
				found,
				string.format("%s: %d/%d texturate", model and model.Name or "?", textured, meshes)
			)
		end
	end
	return found
end

local command = ReplicatedStorage:WaitForChild("PlaytestCmd") :: RemoteEvent
local reply = ReplicatedStorage:WaitForChild("PlaytestReply") :: RemoteEvent
command.OnClientEvent:Connect(function(id: number, op: string, args: { any })
	local handler = ops[op]
	if not handler then
		reply:FireServer(id, false, "operație necunoscută: " .. op)
		return
	end
	local ok, result = pcall(handler, table.unpack(args))
	reply:FireServer(id, ok, result)
end)
reply:FireServer(0, true, "ready")
