--!strict
-- Efectele: zborul papucului cu urma de cusătură roșie, lovitura (hit-stop, shake, confetti),
-- recul pentru jucătorul lovit și avertismentul vizual al Bunicii înainte de aruncare.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Slipper = require(Shared.Domain.Slipper)
local Juice = require(Shared.Config.Juice)
local Sounds = require(Shared.Config.Sounds)
local ClientState = require(script.Parent.ClientState)
local Sfx = require(script.Parent.Sfx)
local Haptics = require(script.Parent.Haptics)
local UI = require(script.Parent.UI)

local EffectsController = {}

local localPlayer = Players.LocalPlayer

type Flying = {
	part: BasePart,
	origin: Vector3,
	velocity: Vector3,
	gravity: number,
	startTime: number,
	lifetime: number,
}

local flying: { [number]: Flying } = {}
local shakeUntil = 0
local shakeStrength = 0

local STITCH_RED = Color3.fromRGB(200, 30, 40)

local function makeProjectile(kind: string): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	if kind == "RollingPin" then
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(3.2, 0.8, 0.8)
		part.Color = Color3.fromRGB(215, 175, 120)
	else
		-- Papucul: talpă plată, cu bareta roșie
		part.Size = Vector3.new(1, 0.35, 2.2)
		part.Color = Color3.fromRGB(110, 70, 50)
		local strap = Instance.new("Part")
		strap.Anchored = false
		strap.CanCollide = false
		strap.Massless = true
		strap.Size = Vector3.new(1.05, 0.3, 0.6)
		strap.Color = STITCH_RED
		strap.CFrame = part.CFrame * CFrame.new(0, 0.25, -0.4)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part
		weld.Part1 = strap
		weld.Parent = strap
		strap.Parent = part
	end
	-- Urma de cusătură roșie
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0, -0.5)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0, 0.5)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(STITCH_RED)
	trail.Lifetime = 0.35
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Parent = part
	part.Parent = Workspace
	return part
end

local function burst(position: Vector3, big: boolean)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = CFrame.new(position)
	holder.Parent = Workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, STITCH_RED),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 80)),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
	})
	emitter.Speed = NumberRange.new(15, 30)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Size = NumberSequence.new(if big then 0.8 else 0.5, 0)
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(if big then 80 else 40)
	task.delay(1.2, function()
		holder:Destroy()
	end)
end

local function shake(strength: number, seconds: number)
	shakeStrength = math.max(shakeStrength, strength)
	shakeUntil = math.max(shakeUntil, os.clock() + seconds)
end

local function onProjectile(info: { [string]: any })
	Sfx.play(Sounds.throwWhoosh, info.origin, 0.5, 0.9 + math.random() * 0.2)
	flying[info.id] = {
		part = makeProjectile(info.kind),
		origin = info.origin,
		velocity = info.velocity,
		gravity = info.gravity,
		startTime = info.startTime,
		lifetime = info.lifetime,
	}
end

-- Text comic mare la locul impactului („PLEOSC!”), care sare și dispare
local function comicText(position: Vector3, text: string, big: boolean)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
	holder.Parent = Workspace
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(if big then 260 else 200, if big then 110 else 80)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.Parent = holder
	local label = UI.label({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = Color3.fromRGB(255, 220, 60),
		TextStrokeColor3 = STITCH_RED,
		TextStrokeTransparency = 0,
		Rotation = math.random(-12, 12),
		Parent = billboard,
	})
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService
		:Create(
			holder,
			TweenInfo.new(Juice.comicTextSeconds),
			{ CFrame = holder.CFrame + Vector3.new(0, 4, 0) }
		)
		:Play()
	task.delay(Juice.comicTextSeconds * 0.6, function()
		TweenService:Create(
			label,
			TweenInfo.new(Juice.comicTextSeconds * 0.4),
			{ TextTransparency = 1, TextStrokeTransparency = 1 }
		):Play()
	end)
	task.delay(Juice.comicTextSeconds + 0.1, function()
		holder:Destroy()
	end)
end

-- „Hit-stop”: camera îngheață o clipă, apoi se strânge (FOV) și revine
local function hitStop(heavy: boolean)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local previousType = camera.CameraType
	local frozen = camera.CFrame
	local fov = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = frozen
	task.delay(Juice.hitStopSeconds * (if heavy then 1.5 else 1), function()
		camera.CameraType = previousType
		camera.FieldOfView = fov - Juice.fovPunch * (if heavy then 1.4 else 1)
		TweenService
			:Create(
				camera,
				TweenInfo.new(Juice.fovRecoverSeconds, Enum.EasingStyle.Quad),
				{ FieldOfView = fov }
			)
			:Play()
	end)
end

local function onHit(info: { [string]: any })
	local projectile = flying[info.id]
	if projectile and info.kind ~= "RollingPin" then
		projectile.part:Destroy()
		flying[info.id] = nil
	end
	local heavy = info.kind == "RollingPin" or info.kind == "Rage"
	local position: Vector3 = info.position
	burst(position, heavy)
	comicText(position, ClientState.t("juice." .. tostring(info.kind)), heavy)
	Sfx.play(if heavy then Sounds.rollingPinHit else Sounds.slipperHit, position, 1)
	Sfx.play(Sounds.thiefScream, position, 0.7, 1 + math.random() * 0.15)
	task.delay(1.1, function()
		Sfx.play(Sounds.bodyFall, position, 0.7)
	end)
	local camera = Workspace.CurrentCamera
	local mine = info.throwerUserId == localPlayer.UserId
	if camera and (camera.CFrame.Position - position).Magnitude < Juice.shakeRadius then
		shake(if heavy then Juice.shakeHeavy else Juice.shakeSlipper, 0.25)
		if mine or info.victimUserId == localPlayer.UserId then
			hitStop(heavy)
		end
	end
	if mine then
		Haptics.impact(heavy)
	end
end

-- Lovitura nopții: la răsărit, toată lumea vede reluarea cu încetinitorul
local function onReplay(best: { [string]: any })
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local part = makeProjectile(best.kind)
	local banner = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 230),
		Size = UDim2.fromOffset(520, 60),
		BackgroundColor3 = STITCH_RED,
		Parent = UI.screen(),
	})
	UI.label({
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		Text = "🏆 " .. ClientState.t("replay.title", { best.name }),
		TextColor3 = UI.colors.linen,
		Parent = banner,
	})
	local previousType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	local duration = math.max(best.duration, 0.3)
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - started) * Juice.replaySpeed, duration)
		local position = Slipper.positionAt(best.origin, best.velocity, best.gravity, t)
		part.CFrame = CFrame.new(position) * CFrame.Angles(t * 14, t * 6, 0)
		local side = best.velocity.Unit:Cross(Vector3.yAxis)
		-- Sus și în lateral, ca nimic din ogradă să nu acopere papucul
		camera.CFrame =
			CFrame.lookAt(position - best.velocity.Unit * 14 + side * 7 + Vector3.new(0, 9, 0), position)
		if t >= duration then
			connection:Disconnect()
			burst(position, true)
			comicText(position, ClientState.t("juice." .. tostring(best.kind)), true)
			Sfx.play(Sounds.slipperHit, nil, 1)
			task.delay(1.2, function()
				part:Destroy()
				banner:Destroy()
				camera.CameraType = previousType
			end)
		end
	end)
end

local function onKnockback(velocity: Vector3, stunSeconds: number)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return
	end
	shake(0.8, 0.35)
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = velocity
	root.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
	task.delay(stunSeconds, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

-- Bunica se înroșește în timpul avertismentului dinaintea aruncării
local function watchBunica(rig: Model)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = STITCH_RED
	highlight.FillTransparency = 0.4
	highlight.OutlineTransparency = 1
	highlight.Enabled = false
	highlight.Parent = rig
	rig:GetAttributeChangedSignal("Windup"):Connect(function()
		highlight.Enabled = rig:GetAttribute("Windup") == true
	end)
end

function EffectsController.start()
	Net.get("Projectile").OnClientEvent:Connect(onProjectile)
	Net.get("Hit").OnClientEvent:Connect(onHit)
	Net.get("Replay").OnClientEvent:Connect(onReplay)
	Net.get("Knockback").OnClientEvent:Connect(onKnockback)

	local village = Workspace:WaitForChild("Village")
	for _, descendant in village:GetDescendants() do
		if descendant:IsA("Model") and descendant.Name == "Bunica" then
			watchBunica(descendant :: Model)
		end
	end
	village.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("Model") and descendant.Name == "Bunica" then
			watchBunica(descendant :: Model)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local now = Workspace:GetServerTimeNow()
		for id, projectile in flying do
			local age = now - projectile.startTime
			if age > projectile.lifetime then
				projectile.part:Destroy()
				flying[id] = nil
				continue
			end
			local position = Slipper.positionAt(
				projectile.origin,
				projectile.velocity,
				projectile.gravity,
				math.max(age, 0)
			)
			-- Papucul se rotește în zbor
			projectile.part.CFrame = CFrame.new(position) * CFrame.Angles(age * 14, age * 6, 0)
			if position.Y < -5 then
				projectile.part:Destroy()
				flying[id] = nil
			end
		end
		local camera = Workspace.CurrentCamera
		if camera and os.clock() < shakeUntil then
			local s = shakeStrength
			camera.CFrame = camera.CFrame
				* CFrame.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
				* CFrame.Angles(0, 0, (math.random() - 0.5) * s * 0.05)
		else
			shakeStrength = 0
		end
	end)
end

return EffectsController
