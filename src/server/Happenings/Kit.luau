--!strict
-- Unelte comune pentru întâmplări: rădăcina unui jucător, cine e aproape, amețeala, figurile NPC simple,
-- mersul lin (tween), punctele libere de pe teren.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local VillageLayout = require(Shared.Domain.VillageLayout)
local ArtLibrary = require(Shared.Visual.ArtLibrary)
local Actors = require(script.Parent.Parent.Actors)
local RaidService = require(script.Parent.Parent.Services.RaidService)

local Kit = {}

local layout = VillageLayout.build()
Kit.layout = layout

function Kit.root(owner: any): BasePart?
	return if owner.actor then Actors.root(owner.actor) else nil
end

-- Cel mai apropiat dintre `owners` de `position` (sub `maxDistance`), cu distanța
function Kit.nearest(owners: { any }, position: Vector3, maxDistance: number): (any?, number)
	local best, bestDistance = nil, maxDistance
	for _, owner in owners do
		local root = Kit.root(owner)
		if root then
			local d = Vector3.new(root.Position.X - position.X, 0, root.Position.Z - position.Z).Magnitude
			if d < bestDistance then
				best, bestDistance = owner, d
			end
		end
	end
	return best, bestDistance
end

-- Încetinește (sau oprește, multiplier 0) un jucător pentru câteva secunde
function Kit.slow(owner: any, name: string, multiplier: number, seconds: number)
	if not owner.actor then
		return
	end
	local actor = owner.actor
	RaidService.setSpeedModifier(actor, name, multiplier)
	task.delay(seconds, function()
		RaidService.setSpeedModifier(actor, name, nil)
	end)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { Workspace.Terrain }

function Kit.groundY(x: number, z: number): number
	local hit = Workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), rayParams)
	return if hit then hit.Position.Y else -1
end

-- Un punct pe teren la cel mult `radius` de `center`, în afara ogrăzilor
function Kit.freePoint(center: Vector3, radius: number, rng: Random): Vector3
	for _ = 1, 40 do
		local angle = rng:NextNumber() * math.pi * 2
		local r = math.sqrt(rng:NextNumber()) * radius
		local p = center + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
		local inside = false
		for _, plot in layout.plots do
			if VillageLayout.contains(plot, p, 3) then
				inside = true
				break
			end
		end
		if not inside then
			return Vector3.new(p.X, Kit.groundY(p.X, p.Z), p.Z)
		end
	end
	return Vector3.new(center.X, Kit.groundY(center.X, center.Z), center.Z)
end

-- Mută lin un model (după PrimaryPart, ancorat) spre `cf` în `seconds`
function Kit.glide(model: Model, cf: CFrame, seconds: number)
	local primary = model.PrimaryPart
	if not primary then
		return
	end
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

-- O piesă ancorată, fără coliziuni, sudată logic în model (CFrame relativ la pivot)
function Kit.piece(
	model: Model,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	offset: CFrame,
	color: Color3
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = model:GetPivot() * offset
	p.Parent = model
	return p
end

-- O figură de om simplă (mătușa, mirii, lăutarii, negustorul)
-- Pune modelul sculptat `key` în `model`, cu baza pe `base` (fața spre −Z), ancorat și fără coliziuni.
-- Întoarce modelul pus sau nil (atunci apelantul construiește figura simplă).
function Kit.sculptInto(model: Model, key: string, base: CFrame, height: number?): Model?
	local art = ArtLibrary.get(key)
	if not art then
		return nil
	end
	if height then
		local _, size = art:GetBoundingBox()
		art:ScaleTo(height / math.max(size.Y, 0.1))
	end
	art:PivotTo(base)
	local box, size = art:GetBoundingBox()
	art:PivotTo(art:GetPivot() + (base.Position - Vector3.new(box.X, box.Y - size.Y / 2, box.Z)))
	for _, part in art:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
		end
	end
	art.Name = "Sculptat"
	art.Parent = model
	return art
end

-- Figurile care au model sculptat (art/models.json); cifra de la final a numelui se ignoră (Lautar1, Lautar2)
Kit.SCULPTED = {
	Negustor = "char.Negustorul",
	NegustorTren = "char.Negustorul",
	Matusa = "char.Marioara",
	MumaPadurii = "char.MumaPadurii",
	Mireasa = "char.Mireasa",
	Mirele = "char.Mirele",
	Lautar = "char.Lautar",
} :: { [string]: string }

function Kit.figure(name: string, at: CFrame, shirt: Color3, parent: Instance, scarf: Color3?): Model
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.Transparency = 1
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = at
	root.Parent = model
	model.PrimaryPart = root
	-- personajul sculptat (TRELLIS), dacă există: aceeași rădăcină, deci glisarea și scalarea merg la fel
	local key = Kit.SCULPTED[string.gsub(name, "%d+$", "")]
	local art = key and ArtLibrary.get(key)
	if art then
		art:PivotTo(at)
		local box, size = art:GetBoundingBox()
		art:PivotTo(art:GetPivot() + (at.Position - Vector3.new(box.X, box.Y - size.Y / 2, box.Z)))
		for _, piece in art:GetDescendants() do
			if piece:IsA("BasePart") then
				piece.Anchored = true
				piece.CanCollide = false
				piece.CanQuery = false
			end
		end
		art.Name = "Sculptat"
		art.Parent = model
		model.Parent = parent
		return model
	end
	local skin = Color3.fromRGB(234, 196, 160)
	Kit.piece(model, "Trup", Enum.PartType.Block, Vector3.new(1.8, 2.2, 1), CFrame.new(0, 3.1, 0), shirt)
	Kit.piece(
		model,
		"Fusta",
		Enum.PartType.Block,
		Vector3.new(2, 2, 1.2),
		CFrame.new(0, 1, 0),
		shirt:Lerp(Color3.new(0, 0, 0), 0.3)
	)
	Kit.piece(model, "Cap", Enum.PartType.Ball, Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 4.8, 0), skin)
	if scarf then
		Kit.piece(
			model,
			"Basma",
			Enum.PartType.Ball,
			Vector3.new(1.45, 1.1, 1.45),
			CFrame.new(0, 5.1, 0.1),
			scarf
		)
	end
	model.Parent = parent
	return model
end

-- Podiumul: după scor, la egalitate cine a început primul. Locurile 1–3, restul 0 (doar participare).
function Kit.placements(scores: { [any]: number }, order: { any }): { [any]: number }
	local ranking = {}
	for owner, score in scores do
		table.insert(ranking, { owner = owner, score = score, first = table.find(order, owner) or math.huge })
	end
	table.sort(ranking, function(a, b)
		return if a.score ~= b.score then a.score > b.score else a.first < b.first
	end)
	local placements = {}
	for place, entry in ranking do
		placements[entry.owner] = if place <= 3 then place else 0
	end
	return placements
end

return Kit
