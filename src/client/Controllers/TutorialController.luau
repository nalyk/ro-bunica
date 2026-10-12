--!strict
-- Primul minut pe client: banner când vine hoțul, indiciu mare + mână animată deasupra lui,
-- apoi mesajul de final. Fără text de citit obligatoriu: mâna arată unde se atinge.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Sounds = require(Shared.Config.Sounds)
local ClientState = require(script.Parent.ClientState)
local UI = require(script.Parent.UI)
local Sfx = require(script.Parent.Sfx)

local TutorialController = {}

local hint: Frame
local hintLabel: TextLabel
local pointer: BillboardGui? = nil
local pulse: RBXScriptConnection? = nil

local function showHint(text: string, color: Color3)
	hintLabel.Text = text
	hint.BackgroundColor3 = color
	hint.Visible = true
	hint.Size = UDim2.fromOffset(0, 70)
	TweenService
		:Create(hint, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(560, 70) })
		:Play()
end

-- Un scurt cadru cinematic spre hoț (camera implicită și-ar anula rotirea), apoi controlul revine
local function focusOn(name: string)
	local model = Workspace:FindFirstChild(name)
	local target = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local character = game:GetService("Players").LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = Workspace.CurrentCamera
	if not target or not root or not camera then
		return
	end
	local away = root.Position - target.Position
	local flat = Vector3.new(away.X, 0, away.Z)
	local back = if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis
	local previousType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(camera, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
		CFrame = CFrame.lookAt(root.Position + back * 12 + Vector3.new(0, 7, 0), target.Position),
	}):Play()
	task.delay(1.2, function()
		camera.CameraType = previousType
	end)
end

-- Săgeată la marginea ecranului spre hoț, cât timp e în afara câmpului vizual
local edgeArrow: TextLabel? = nil
local edgeConnection: RBXScriptConnection? = nil

local function trackOffscreen(name: string)
	local arrow = UI.label({
		Size = UDim2.fromOffset(70, 70),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Text = "➤",
		TextColor3 = UI.colors.stitch,
		TextStrokeColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0,
		Visible = false,
		Parent = UI.screen(),
	})
	edgeArrow = arrow
	edgeConnection = RunService.RenderStepped:Connect(function()
		local model = Workspace:FindFirstChild(name)
		local target = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
		local camera = Workspace.CurrentCamera
		if not target or not camera then
			arrow.Visible = false
			return
		end
		local point, onScreen = camera:WorldToViewportPoint(target.Position)
		local size = camera.ViewportSize
		if onScreen then
			arrow.Visible = false
			return
		end
		-- Direcția spre țintă, din centrul ecranului; în spatele camerei se inversează
		local direction = Vector2.new(point.X - size.X / 2, point.Y - size.Y / 2)
		if point.Z < 0 then
			direction = -direction
		end
		if direction.Magnitude < 1 then
			direction = Vector2.new(0, 1)
		end
		direction = direction.Unit
		local margin = 60
		local scale = math.min(
			(size.X / 2 - margin) / math.abs(direction.X + 1e-6),
			(size.Y / 2 - margin) / math.abs(direction.Y + 1e-6)
		)
		local position = Vector2.new(size.X / 2, size.Y / 2) + direction * scale
		arrow.Position = UDim2.fromOffset(position.X, position.Y)
		arrow.Rotation = math.deg(math.atan2(direction.Y, direction.X))
		arrow.Visible = true
	end)
end

local function stopTracking()
	if edgeConnection then
		edgeConnection:Disconnect()
		edgeConnection = nil
	end
	if edgeArrow then
		edgeArrow:Destroy()
		edgeArrow = nil
	end
end

local function hideHint()
	hint.Visible = false
	stopTracking()
	if pulse then
		pulse:Disconnect()
		pulse = nil
	end
	if pointer then
		pointer:Destroy()
		pointer = nil
	end
end

-- O mână mare care sare deasupra hoțului
local function pointAt(name: string)
	local model = Workspace:FindFirstChild(name)
	local head = model and model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(90, 90)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = head
	local hand = UI.label({ Size = UDim2.fromScale(1, 1), Text = "👇", Parent = billboard })
	billboard.Parent = head
	pointer = billboard
	pulse = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		billboard.StudsOffset = Vector3.new(0, 6 + math.abs(math.sin(t * 6)) * 1.5, 0)
		hand.TextTransparency = 0
	end)
end

function TutorialController.start()
	hint = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(560, 70),
		Visible = false,
		Parent = UI.screen(),
	})
	hintLabel = UI.label({
		Size = UDim2.new(1, -20, 1, -10),
		Position = UDim2.fromOffset(10, 5),
		Text = "",
		TextColor3 = UI.colors.linen,
		Parent = hint,
	})

	Net.get("Tutorial").OnClientEvent:Connect(function(stage: string, data: { any }?)
		local args = data or {}
		if stage == "incoming" then
			Sfx.play(Sounds.alarm, nil, 0.6)
			showHint("🐓 " .. ClientState.t("tutorial.incoming"), UI.colors.night)
		elseif stage == "throw" then
			showHint(ClientState.t("tutorial.throw"), UI.colors.stitch)
			pointAt(tostring(args[1]))
			focusOn(tostring(args[1]))
			trackOffscreen(tostring(args[1]))
		elseif stage == "done" then
			hideHint()
			local byPlayer = args[1] == true
			showHint(
				ClientState.t(if byPlayer then "tutorial.doneByPlayer" else "tutorial.doneByBunica"),
				UI.colors.green
			)
			task.delay(4, hideHint)
		end
	end)
end

return TutorialController
