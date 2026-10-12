--!strict
-- Efectele: zborul papucului cu urma de cusătură roșie, lovitura (hit-stop, shake, confetti),
-- recul pentru jucătorul lovit și avertismentul vizual al Bunicii înainte de aruncare.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Slipper = require(Shared.Domain.Slipper)

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
	flying[info.id] = {
		part = makeProjectile(info.kind),
		origin = info.origin,
		velocity = info.velocity,
		gravity = info.gravity,
		startTime = info.startTime,
		lifetime = info.lifetime,
	}
end

local function onHit(info: { [string]: any })
	local projectile = flying[info.id]
	if projectile and info.kind ~= "RollingPin" then
		projectile.part:Destroy()
		flying[info.id] = nil
	end
	local big = info.kind == "RollingPin" or info.kind == "Rage"
	burst(info.position, big)
	local camera = Workspace.CurrentCamera
	if camera and (camera.CFrame.Position - info.position).Magnitude < 80 then
		shake(if big then 0.6 else 0.35, 0.25)
	end
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
