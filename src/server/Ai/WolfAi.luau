--!strict
-- Un lup comic (Lupii la stână): vine din codru spre țarc în salturi scurte; lovit de papuc se oprește și
-- schelălăie; gonit (2 lovituri) fuge înapoi în codru și dispare. Piese ancorate, mișcate lin (TweenService).

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local WolfAi = {}

export type Wolf = {
	model: Model,
	hits: number,
	state: "Coming" | "Stunned" | "Fleeing" | "InPen" | "Gone",
	stunnedUntil: number,
}

local GREY, DARK = Color3.fromRGB(120, 120, 128), Color3.fromRGB(70, 70, 76)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { Workspace.Terrain }

local function ground(p: Vector3): Vector3
	local hit = Workspace:Raycast(Vector3.new(p.X, 300, p.Z), Vector3.new(0, -600, 0), rayParams)
	return Vector3.new(p.X, if hit then hit.Position.Y else -1, p.Z)
end

local function piece(
	model: Model,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	shape: Enum.PartType?
)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Shape = shape or Enum.PartType.Block
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CFrame = model:GetPivot() * offset
	p.Parent = model
end

function WolfAi.create(at: Vector3, parent: Instance): Wolf
	local model = Instance.new("Model")
	model.Name = "Lup"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.Transparency = 1
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = CFrame.new(ground(at) + Vector3.new(0, 1.6, 0))
	root.Parent = model
	model.PrimaryPart = root
	local Kit = require(script.Parent.Parent.Happenings.Kit)
	if Kit.sculptInto(model, "char.Lupul", root.CFrame * CFrame.new(0, -1.5, 0), 3.2) then
		model:SetAttribute("Wolf", true)
		model.Parent = parent
		return { model = model, hits = 0, state = "Coming", stunnedUntil = 0 }
	end
	piece(model, "Corp", Vector3.new(1.6, 1.5, 3.4), CFrame.new(0, 0.4, 0), GREY)
	piece(model, "Cap", Vector3.new(1.3, 1.2, 1.4), CFrame.new(0, 1.1, -2), GREY)
	piece(model, "Bot", Vector3.new(0.7, 0.6, 0.9), CFrame.new(0, 0.85, -2.9), DARK)
	piece(model, "UrecheS", Vector3.new(0.35, 0.6, 0.25), CFrame.new(-0.4, 1.95, -1.9), DARK)
	piece(model, "UrecheD", Vector3.new(0.35, 0.6, 0.25), CFrame.new(0.4, 1.95, -1.9), DARK)
	piece(
		model,
		"Coada",
		Vector3.new(0.35, 0.35, 1.6),
		CFrame.new(0, 0.9, 2.2) * CFrame.Angles(math.rad(25), 0, 0),
		GREY
	)
	for _, x in { -0.55, 0.55 } do
		for _, z in { -1.2, 1.2 } do
			piece(model, "Laba", Vector3.new(0.4, 1.4, 0.4), CFrame.new(x, -0.8, z), DARK)
		end
	end
	model:SetAttribute("Wolf", true)
	model.Parent = parent
	return { model = model, hits = 0, state = "Coming", stunnedUntil = 0 }
end

local function glide(model: Model, cf: CFrame, seconds: number)
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	value.Changed:Connect(function(v)
		model:PivotTo(v)
	end)
	local tween = TweenService:Create(value, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Value = cf })
	tween.Completed:Connect(function()
		value:Destroy()
	end)
	tween:Play()
end

-- Un pas de `dt` spre `target` cu viteza `speed`; întoarce distanța orizontală rămasă
function WolfAi.step(wolf: Wolf, target: Vector3, speed: number, dt: number): number
	local from = wolf.model:GetPivot().Position
	local flat = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
	if flat.Magnitude < 0.5 then
		return flat.Magnitude
	end
	local move = flat.Unit * math.min(flat.Magnitude, speed * dt)
	local to = ground(from + move) + Vector3.new(0, 1.6 + math.abs(math.sin(os.clock() * 9)) * 0.3, 0)
	glide(wolf.model, CFrame.lookAt(to, to + flat.Unit), dt)
	return flat.Magnitude - move.Magnitude
end

return WolfAi
