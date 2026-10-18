--!strict
-- Construiește modelul unei creaturi: modelul final din `modelId` (dacă există) sau placeholder procedural.
-- Modelul e ancorat și fără coliziuni; animația și eticheta se fac local, pe client.

local CollectionService = game:GetService("CollectionService")

local ArtLibrary = require(script.Parent.ArtLibrary)
local MutationVisuals = require(script.Parent.MutationVisuals)
local Config = script.Parent.Parent.Config
local Creatures = require(Config.Creatures)
local Mutations = require(Config.Mutations)
local Sizes = require(Config.Sizes)

local CreatureBuilder = {}

CreatureBuilder.TAG = "Creature"

type Record = { uid: string?, id: string, size: string, mutation: string? }

local SHAPES: { [string]: Enum.PartType } = {
	Block = Enum.PartType.Block,
	Cylinder = Enum.PartType.Cylinder,
}

local function makePart(shape: string, size: Vector3, color: Color3): BasePart
	local part: BasePart
	if shape == "Wedge" then
		part = Instance.new("WedgePart")
	elseif shape == "Ball" then
		-- O parte Ball e forțată la dimensiuni egale; un mesh sferic permite elipsoizi
		part = Instance.new("Part")
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	else
		local p = Instance.new("Part")
		p.Shape = SHAPES[shape] or Enum.PartType.Block
		part = p
	end
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	return part
end

-- Doi ochi mari pe fața corpului (-Z): fac orice formă să pară un personaj.
local function addEyes(model: Model, body: BasePart)
	local half = body.Size / 2
	for _, side in { -1, 1 } do
		local white = makePart("Ball", Vector3.new(0.7, 0.7, 0.7), Color3.new(1, 1, 1))
		white.CFrame = body.CFrame * CFrame.new(side * half.X * 0.35, half.Y * 0.35, -half.Z * 0.92)
		white.Name = "Eye"
		white.Parent = model
		local pupil = makePart("Ball", Vector3.new(0.35, 0.35, 0.35), Color3.new(0.05, 0.05, 0.05))
		pupil.CFrame = white.CFrame * CFrame.new(0, 0, -0.25)
		pupil.Name = "Pupil"
		pupil.Parent = model
	end
end

local function buildProcedural(creatureId: string): Model
	local creature = Creatures.byId[creatureId]
	local model = Instance.new("Model")
	local body = makePart(creature.look.body.shape, creature.look.body.size, creature.look.body.color)
	body.Name = "Body"
	body.CFrame = CFrame.new()
	body.Parent = model
	model.PrimaryPart = body
	for index, look in creature.look.parts do
		local part = makePart(look.shape, look.size, look.color)
		part.Name = "Detail" .. index
		part.CFrame = CFrame.new(look.offset)
		part.Parent = model
	end
	addEyes(model, body)
	return model
end

local function applyMutation(model: Model, mutationId: string?)
	local mutation = mutationId and Mutations.byId[mutationId]
	MutationVisuals.apply(model, mutationId, if mutation then mutation.color else nil)
end

-- Așază modelul cu baza (cu tot cu detaliile de dedesubt) exact pe `pivot`.
-- Cu PrimaryPart setat, WorldPivot nu se poate muta, deci măsurăm și corectăm pe verticală.
function CreatureBuilder.placeOn(model: Model, pivot: CFrame)
	model:PivotTo(pivot)
	local box, extents = model:GetBoundingBox()
	local bottom = box.Position.Y - extents.Y / 2
	model:PivotTo(model:GetPivot() + Vector3.new(0, pivot.Position.Y - bottom, 0))
end

-- Desprinde modelul de pe piedestal și îl sudează deasupra capului unui personaj (cărat).
function CreatureBuilder.attachAbove(model: Model, root: BasePart, height: number)
	local primary = model.PrimaryPart :: BasePart
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = true
			descendant.CanCollide = false
			if descendant ~= primary then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primary
				weld.Part1 = descendant
				weld.Parent = descendant
			end
		end
	end
	model:PivotTo(root.CFrame * CFrame.new(0, height + model:GetExtentsSize().Y / 2, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = primary
	weld.Parent = primary
	model.Parent = root.Parent
end

-- Construiește modelul (fără Parent). `pivot` = unde stă baza modelului.
function CreatureBuilder.build(record: Record, pivot: CFrame): Model
	local creature = Creatures.byId[record.id]
	assert(creature, "Creatură necunoscută: " .. record.id)
	-- Modelul final (art/creatures, încărcat de ArtService); fără el, forma procedurală
	local model = ArtLibrary.get("creature." .. record.id) or buildProcedural(record.id)
	model.Name = record.id

	local size = Sizes.byId[record.size]
	if size and size.scale ~= 1 then
		model:ScaleTo(size.scale)
	end
	applyMutation(model, record.mutation)

	CreatureBuilder.placeOn(model, pivot)

	-- hibridul: a doua creatură, micșorată, stă pe capul primei („pălăria”), în același model
	local hybrid = (record :: any).hybrid :: string?
	if hybrid and Creatures.byId[hybrid] then
		local hat = ArtLibrary.get("creature." .. hybrid) or buildProcedural(hybrid)
		hat:ScaleTo(0.45)
		local box, extent = model:GetBoundingBox()
		CreatureBuilder.placeOn(
			hat,
			CFrame.new(box.Position + Vector3.new(0, extent.Y / 2 - 0.2, 0)) * pivot.Rotation
		)
		for _, part in hat:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
			end
		end
		for _, child in hat:GetChildren() do
			child.Parent = model
		end
		hat:Destroy()
		model:SetAttribute("Hybrid", hybrid)
		model:SetAttribute("HybridName", (record :: any).hybridName or "")
	end

	model:SetAttribute("CreatureId", record.id)
	model:SetAttribute("Size", record.size)
	model:SetAttribute("Mutation", record.mutation or "")
	model:SetAttribute("Soul", (record :: any).soul == true)
	if record.uid then
		model:SetAttribute("Uid", record.uid)
	end
	CollectionService:AddTag(model, CreatureBuilder.TAG)
	return model
end

return CreatureBuilder
