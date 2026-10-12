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
	prompt:InputHoldBegin()
	task.wait(prompt.HoldDuration + 0.4)
	prompt:InputHoldEnd()
	return "ok"
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
		papuci = (function()
			local stats = player:FindFirstChild("leaderstats")
			local value = stats and stats:FindFirstChild("Papuci") :: IntValue?
			return if value then value.Value else -1
		end)(),
		position = (character():FindFirstChild("HumanoidRootPart") :: BasePart).Position,
	}
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
