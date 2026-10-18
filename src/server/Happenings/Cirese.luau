--!strict
-- Ploaie de cireșe: livada scutură 40 de cireșe pe jos. Le aduni trecând peste ele (5 lei fiecare). Mătușa
-- Mărioara își păzește cireșii: îl urmărește pe cel mai apropiat culegător, iar dacă te ajunge te prinde
-- în urzici (stai pe loc o secundă). Se termină când nu mai rămâne nicio cireașă.

local Kit = require(script.Parent.Kit)

local Cirese = {}

local COUNT = 40
local PICK_DISTANCE = 4
local LEI = 5
local AUNT_SPEED = 9 -- mai încet decât un copil care fuge (16)
local AUNT_REACH = 3.2
local AUNT_RANGE = 45 -- nu iese din livadă după tine
local RED = Color3.fromRGB(200, 20, 40)

Cirese.COUNT = COUNT
Cirese.LEI = LEI

function Cirese.start(ctx: any)
	local rng = Random.new()
	local center = ctx.site.Position
	local sites = workspace:FindFirstChild("Village") and workspace.Village:FindFirstChild("Sites")
	local livada = sites and sites:FindFirstChild("livada")
	-- sub fiecare cireș (repere Cires1..5), altfel în jurul centrului livezii
	local trees = {}
	for i = 1, 5 do
		local marker = livada and livada:FindFirstChild("Cires" .. i)
		table.insert(trees, if marker and marker:IsA("BasePart") then marker.Position else center)
	end
	local cherries: { BasePart } = {}
	for i = 1, COUNT do
		local tree = trees[(i - 1) % #trees + 1]
		local p = Kit.freePoint(tree, 7, rng)
		local cherry = Instance.new("Part")
		cherry.Name = "Cireasa"
		cherry.Shape = Enum.PartType.Ball
		cherry.Size = Vector3.new(0.9, 0.9, 0.9)
		cherry.Color = RED
		cherry.Material = Enum.Material.SmoothPlastic
		cherry.Anchored = true
		cherry.CanCollide = false
		cherry.CanQuery = false
		cherry.CanTouch = false
		cherry.Position = p + Vector3.new(0, 0.5, 0)
		cherry.Parent = ctx.folder
		table.insert(cherries, cherry)
	end
	ctx.data.cherries = cherries
	ctx.data.scores = {}
	ctx.data.order = {}
	ctx.data.home = center
	local marker = livada and livada:FindFirstChild("Matusa")
	local at = if marker and marker:IsA("BasePart") then marker.Position else center
	ctx.data.aunt = Kit.figure(
		"Matusa",
		CFrame.new(at.X, Kit.groundY(at.X, at.Z), at.Z),
		Color3.fromRGB(150, 60, 70),
		ctx.folder,
		Color3.fromRGB(240, 220, 120)
	)
	ctx.data.auntBusy = 0
end

function Cirese.remaining(ctx: any): number
	local n = 0
	for _, cherry in ctx.data.cherries :: { BasePart } do
		if cherry.Parent then
			n += 1
		end
	end
	return n
end

function Cirese.tick(ctx: any, dt: number)
	local owners = ctx.owners()
	for _, cherry in ctx.data.cherries :: { BasePart } do
		if cherry.Parent then
			local picker = Kit.nearest(owners, cherry.Position, PICK_DISTANCE)
			if picker then
				cherry:Destroy()
				ctx.participate(picker)
				ctx.give(picker, LEI)
				ctx.data.scores[picker] = (ctx.data.scores[picker] or 0) + 1
				if not table.find(ctx.data.order, picker) then
					table.insert(ctx.data.order, picker)
				end
			end
		end
	end
	-- mătușa: după cel mai apropiat culegător din livadă; acasă dacă nu e nimeni
	local aunt: Model = ctx.data.aunt
	local position = aunt:GetPivot().Position
	local home: Vector3 = ctx.data.home
	local target = Kit.nearest(owners, home, AUNT_RANGE)
	local goal = home
	if target then
		local root = Kit.root(target)
		if root then
			goal = root.Position
			local d = Vector3.new(goal.X - position.X, 0, goal.Z - position.Z).Magnitude
			if d <= AUNT_REACH and os.clock() >= ctx.data.auntBusy then
				Kit.slow(target, "nettles", 0, 1) -- urzicile: o secundă pe loc
				ctx.data.auntBusy = os.clock() + 2.5
			end
		end
	end
	local step = Vector3.new(goal.X - position.X, 0, goal.Z - position.Z)
	if step.Magnitude > 0.5 then
		local move = step.Unit * math.min(step.Magnitude, AUNT_SPEED * dt)
		local to = position + move
		to = Vector3.new(to.X, Kit.groundY(to.X, to.Z), to.Z)
		Kit.glide(aunt, CFrame.lookAt(to, to + step.Unit), dt)
	end
	if Cirese.remaining(ctx) == 0 then
		ctx.finish()
	end
end

function Cirese.stop(ctx: any): { [any]: number }
	return Kit.placements(ctx.data.scores, ctx.data.order)
end

return Cirese
