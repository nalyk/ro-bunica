--!strict
-- Gâștele au scăpat: 12 gâște rătăcesc prin sat. Te apropii de una și o iei în brațe; o duci la țarcul din
-- centru: 30 de lei. Gâștele libere mai ciupesc pe cine trece pe lângă ele (te încetinesc o clipă).

local Kit = require(script.Parent.Kit)

local Gaste = {}

local COUNT = 12
local CATCH_DISTANCE = 4.5
local PEN_DISTANCE = 9
local LEI = 30
local SPEED = 5
local PECK_DISTANCE = 6
local PECK_CHANCE = 0.08 -- pe tick, lângă o gâscă liberă
local WHITE, ORANGE = Color3.fromRGB(246, 246, 240), Color3.fromRGB(240, 150, 40)

Gaste.COUNT = COUNT
Gaste.LEI = LEI

type Goose = { model: Model, carrier: any?, target: Vector3, busyUntil: number }

local function goose(at: Vector3, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Gasca"
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
	if Kit.sculptInto(model, "char.Gasca", root.CFrame, 3) then
		model:SetAttribute("Goose", true)
		model.Parent = parent
		return model
	end
	Kit.piece(model, "Corp", Enum.PartType.Ball, Vector3.new(1.6, 1.4, 2.3), CFrame.new(0, 1, 0), WHITE)
	Kit.piece(model, "Gat", Enum.PartType.Block, Vector3.new(0.45, 1.5, 0.45), CFrame.new(0, 2, -0.9), WHITE)
	Kit.piece(model, "Cap", Enum.PartType.Ball, Vector3.new(0.7, 0.7, 0.8), CFrame.new(0, 2.8, -1), WHITE)
	Kit.piece(
		model,
		"Cioc",
		Enum.PartType.Block,
		Vector3.new(0.3, 0.25, 0.6),
		CFrame.new(0, 2.75, -1.5),
		ORANGE
	)
	model:SetAttribute("Goose", true)
	model.Parent = parent
	return model
end

local function pen(ctx: any): Vector3
	return ctx.data.pen :: Vector3
end

function Gaste.start(ctx: any)
	local rng = Random.new()
	local center = ctx.site.Position
	-- țarcul din centru (SiteBuilder: Sites.centru.Tarc); altfel lângă centru
	local sites = workspace:FindFirstChild("Village") and workspace.Village:FindFirstChild("Sites")
	local marker = sites and sites:FindFirstChild("centru") and sites.centru:FindFirstChild("TarcZona", true)
	ctx.data.pen = if marker and marker:IsA("BasePart")
		then marker.Position
		else center + Vector3.new(26, 0, 4)
	ctx.data.rng = rng
	ctx.data.scores = {}
	ctx.data.order = {}
	local geese: { Goose } = {}
	for _ = 1, COUNT do
		local at = Kit.freePoint(center, 140, rng)
		table.insert(geese, { model = goose(at, ctx.folder), carrier = nil, target = at, busyUntil = 0 })
	end
	ctx.data.geese = geese
end

-- Pentru teste: gâștele (modelele) și cine o cară pe fiecare
function Gaste.geese(ctx: any): { Goose }
	return ctx.data.geese
end

function Gaste.tick(ctx: any, _dt: number)
	local owners = ctx.owners()
	local rng: Random = ctx.data.rng
	local now = os.clock()
	for _, g in ctx.data.geese :: { Goose } do
		if not g.model.Parent then
			continue
		end
		if g.carrier then
			local root = Kit.root(g.carrier)
			if not root then
				g.carrier = nil
				continue
			end
			-- în brațe, deasupra capului; la țarc, intră și se numără
			g.model:PivotTo(CFrame.new(root.Position + Vector3.new(0, 2.6, 0)) * root.CFrame.Rotation)
			local flat = Vector3.new(root.Position.X - pen(ctx).X, 0, root.Position.Z - pen(ctx).Z)
			if flat.Magnitude <= PEN_DISTANCE then
				local owner = g.carrier
				g.carrier = nil
				g.model:PivotTo(
					CFrame.new(pen(ctx) + Vector3.new(rng:NextNumber(-3, 3), -1.5, rng:NextNumber(-3, 3)))
				)
				g.model:SetAttribute("Penned", true)
				g.model:SetAttribute("CarrierUserId", nil)
				ctx.participate(owner)
				ctx.give(owner, LEI)
				ctx.data.scores[owner] = (ctx.data.scores[owner] or 0) + 1
				table.insert(ctx.data.order, owner)
			end
			continue
		end
		if g.model:GetAttribute("Penned") then
			continue
		end
		-- cine e destul de aproape o ia în brațe (unul singur pe rând)
		local catcher = Kit.nearest(owners, g.model:GetPivot().Position, CATCH_DISTANCE)
		if catcher then
			local carrying = false
			for _, other in ctx.data.geese :: { Goose } do
				carrying = carrying or other.carrier == catcher
			end
			if not carrying then
				g.carrier = catcher
				g.model:SetAttribute("CarrierUserId", catcher.userId)
				ctx.participate(catcher)
				continue
			end
		end
		local pecker = Kit.nearest(owners, g.model:GetPivot().Position, PECK_DISTANCE)
		if pecker and rng:NextNumber() < PECK_CHANCE then
			Kit.slow(pecker, "goosePeck", 0.6, 1)
		end
		-- rătăcește: o țintă nouă la câțiva pași, mers lin
		if now >= g.busyUntil then
			local from = g.model:GetPivot().Position
			local to = Kit.freePoint(from, 14, rng)
			local seconds = (to - from).Magnitude / SPEED + 0.01
			g.busyUntil = now + seconds + rng:NextNumber(0.2, 1.5)
			local look = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
			Kit.glide(
				g.model,
				if look.Magnitude > 0.1 then CFrame.lookAt(to, to + look) else CFrame.new(to),
				seconds
			)
		end
	end
	-- toate în țarc: gata mai devreme
	local free = 0
	for _, g in ctx.data.geese :: { Goose } do
		if not g.model:GetAttribute("Penned") then
			free += 1
		end
	end
	if free == 0 then
		ctx.finish()
	end
end

function Gaste.stop(ctx: any): { [any]: number }
	return Kit.placements(ctx.data.scores, ctx.data.order)
end

return Gaste
