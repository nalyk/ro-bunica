--!strict
-- Prinde cocoșul (2–8 jucători, 60 s, în centru): cocoșul fuge de jucătorii din apropiere (cei mai apropiați
-- contează mai mult) și nu iese din arenă. Cine îl atinge îl prinde (1 punct), iar cocoșul reapare în altă
-- parte. Fuge mai încet decât un copil, dar se întoarce brusc.

local Kit = require(script.Parent.Parent.Happenings.Kit)

local Cocos = {}

Cocos.ARENA = 28
Cocos.CATCH = 3.5
local SPEED = 12
local RED, GOLD = Color3.fromRGB(200, 40, 30), Color3.fromRGB(230, 170, 50)

local function buildRooster(at: Vector3, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Cocos"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.Transparency = 1
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = CFrame.new(at)
	root.Parent = model
	model.PrimaryPart = root
	-- cocoșul: găina sculptată, mai mare, cu creasta înaltă și coada arcuită (generatorul de imagini nu face cocoși)
	local art = Kit.sculptInto(model, "char.Gaina", root.CFrame, 2.4)
	if art then
		local box, size = art:GetBoundingBox()
		local top = (root.CFrame:Inverse() * box).Position + Vector3.new(0, size.Y / 2, 0)
		Kit.piece(
			model,
			"Creasta",
			Enum.PartType.Block,
			Vector3.new(0.18, 0.6, 0.7),
			CFrame.new(0, top.Y + 0.15, top.Z - size.Z * 0.25),
			RED
		)
		Kit.piece(
			model,
			"Coada",
			Enum.PartType.Block,
			Vector3.new(0.3, 1.8, 1.1),
			CFrame.new(0, top.Y - 0.3, top.Z + size.Z * 0.45) * CFrame.Angles(math.rad(-20), 0, 0),
			Color3.fromRGB(40, 90, 60)
		)
		model.Parent = parent
		return model
	end
	Kit.piece(model, "Corp", Enum.PartType.Ball, Vector3.new(1.4, 1.4, 1.8), CFrame.new(0, 1, 0), GOLD)
	Kit.piece(
		model,
		"Coada",
		Enum.PartType.Block,
		Vector3.new(0.3, 1.6, 1),
		CFrame.new(0, 1.8, 0.9) * CFrame.Angles(math.rad(-20), 0, 0),
		Color3.fromRGB(40, 90, 60)
	)
	Kit.piece(model, "Cap", Enum.PartType.Ball, Vector3.new(0.7, 0.8, 0.7), CFrame.new(0, 2.1, -0.8), GOLD)
	Kit.piece(
		model,
		"Creasta",
		Enum.PartType.Block,
		Vector3.new(0.15, 0.5, 0.6),
		CFrame.new(0, 2.6, -0.8),
		RED
	)
	model.Parent = parent
	return model
end

local function respawn(match: any)
	local rng: Random = match.data.rng
	local center = match.arena.Position
	local angle = rng:NextNumber() * math.pi * 2
	local r = rng:NextNumber(6, Cocos.ARENA - 4)
	local p = center + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
	match.data.rooster:PivotTo(CFrame.new(p.X, Kit.groundY(p.X, p.Z), p.Z))
end

function Cocos.setup(match: any)
	match.data.rng = Random.new()
	local center = match.arena.Position
	match.data.rooster =
		buildRooster(Vector3.new(center.X, Kit.groundY(center.X, center.Z), center.Z), match.folder)
	respawn(match)
	match.publish({})
end

function Cocos.rooster(match: any): Model
	return match.data.rooster
end

function Cocos.tick(match: any, dt: number)
	local rooster: Model = match.data.rooster
	local position = rooster:GetPivot().Position
	local center = match.arena.Position
	local flee = Vector3.zero
	for _, owner in match.players do
		local root = Kit.root(owner)
		if root and not match.isGhost(owner) then
			local away = Vector3.new(position.X - root.Position.X, 0, position.Z - root.Position.Z)
			local d = away.Magnitude
			if d <= Cocos.CATCH then
				match.score(owner, 1)
				respawn(match)
				match.publish({})
				return
			end
			if d < 24 then
				flee += away.Unit / math.max(d, 1) -- cei apropiați contează mai mult
			end
		end
	end
	-- spre centru dacă iese din arenă, plus un zigzag
	local toCenter = Vector3.new(center.X - position.X, 0, center.Z - position.Z)
	if toCenter.Magnitude > Cocos.ARENA - 3 then
		flee += toCenter.Unit * 0.6
	end
	if flee.Magnitude < 1e-3 then
		return
	end
	local zig = math.sin(os.clock() * 5) * 0.5
	local dir = (flee.Unit + flee.Unit:Cross(Vector3.yAxis) * zig).Unit
	local to = position + dir * SPEED * dt
	to = Vector3.new(to.X, Kit.groundY(to.X, to.Z), to.Z)
	Kit.glide(rooster, CFrame.lookAt(to, to + dir), dt)
end

return Cocos
