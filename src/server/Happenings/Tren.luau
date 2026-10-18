--!strict
-- Trenul de la Ungheni (cel mult o dată pe oră): vine pe linie, oprește la gară (schimbă roțile, ca la
-- granița cu ecartament diferit) și pleacă. Negustorul din tren vinde fiecărui jucător câte o sămânță
-- Legendară la jumătate de preț (acțiunea { buy = true }, pe peron). Cât merge, trenul amețește pe cine
-- prinde pe linie: un hoț care fuge peste șine e oprit pe loc.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Village = require(Shared.Config.Village)
local Kit = require(script.Parent.Kit)
local ShopService = require(script.Parent.Parent.Services.ShopService)
local Messenger = require(script.Parent.Parent.Services.Messenger)

local Tren = {}

Tren.ARRIVE = 12 -- secunde până oprește în gară
Tren.LEAVE = 10 -- ultimele secunde: pleacă
Tren.REACH = 22 -- de pe peron
Tren.DISCOUNT = 0.5
local LINE_HIT = 4.5

local function car(model: Model, name: string, length: number, color: Color3, offsetX: number)
	local body = Instance.new("Part")
	body.Name = name
	body.Size = Vector3.new(length, 7, 6)
	body.Color = color
	body.Material = Enum.Material.Metal
	body.Anchored = true
	body.CanCollide = true
	body.CFrame = model:GetPivot() * CFrame.new(offsetX, 4.5, 0)
	body.Parent = model
	for _, x in { -length / 2 + 2, length / 2 - 2 } do
		for _, z in { -2.6, 2.6 } do
			local wheel = Instance.new("Part")
			wheel.Name = "Roata"
			wheel.Shape = Enum.PartType.Cylinder
			wheel.Size = Vector3.new(0.6, 2.4, 2.4)
			wheel.Color = Color3.fromRGB(40, 40, 40)
			wheel.Anchored = true
			wheel.CanCollide = false
			wheel.CFrame = model:GetPivot()
				* CFrame.new(offsetX + x, 1.2, z)
				* CFrame.Angles(0, math.pi / 2, 0)
			wheel.Parent = model
		end
	end
end

local function stationX(ctx: any): number
	return ctx.site.Position.X
end

local function trainAt(_ctx: any, x: number): CFrame
	local z = Village.railwayZ
	local y = Kit.groundY(x, z) + 0.6
	return CFrame.new(x, y, z)
end

function Tren.start(ctx: any)
	local model = Instance.new("Model")
	model.Name = "Tren"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.Transparency = 1
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = trainAt(ctx, stationX(ctx) - 520)
	root.Parent = model
	model.PrimaryPart = root
	car(model, "Locomotiva", 16, Color3.fromRGB(40, 110, 70), 0)
	car(model, "Vagon1", 20, Color3.fromRGB(150, 40, 40), -19)
	car(model, "Vagon2", 20, Color3.fromRGB(150, 40, 40), -40)
	model.Parent = ctx.folder
	ctx.data.train = model
	ctx.data.state = "Arriving"
	ctx.data.buyers = {}
	local legendaries = {}
	for _, creature in Creatures.list do
		if creature.rarity == "Legendary" and creature.seedPrice then
			table.insert(legendaries, creature.id)
		end
	end
	local seed = if #legendaries > 0 then legendaries[math.random(1, #legendaries)] else nil
	ctx.data.offer = seed
		and { seedId = seed, price = math.floor((Creatures.byId[seed].seedPrice :: number) * Tren.DISCOUNT) }
	local platform = ctx.site.Position + Vector3.new(0, 0, 2)
	ctx.data.platform = platform
	ctx.data.merchant = Kit.figure(
		"NegustorTren",
		CFrame.new(platform.X + 6, Kit.groundY(platform.X, platform.Z) + 1, platform.Z),
		Color3.fromRGB(30, 50, 90),
		ctx.folder
	)
	Kit.glide(model, trainAt(ctx, stationX(ctx)), Tren.ARRIVE)
	ctx.publish({ offers = if ctx.data.offer then { ctx.data.offer } else {}, merchant = platform })
end

function Tren.state(ctx: any): string
	return ctx.data.state
end

function Tren.action(ctx: any, owner: any, payload: any)
	local offer = ctx.data.offer
	if not offer or typeof(payload) ~= "table" or ctx.data.buyers[owner] or ctx.data.state ~= "Stopped" then
		return
	end
	local root = Kit.root(owner)
	if not root or (root.Position - ctx.data.platform).Magnitude > Tren.REACH then
		return
	end
	if ShopService.offer(owner, offer.seedId, offer.price) then
		ctx.data.buyers[owner] = true
		ctx.participate(owner)
		if owner.player then
			Messenger.notify(
				owner.player,
				"happening.trainSeed",
				{ Messenger.key("creature." .. offer.seedId) }
			)
		end
	end
end

function Tren.tick(ctx: any, _dt: number)
	local now = workspace:GetServerTimeNow()
	local elapsed = now - ctx.startedAt
	local left = ctx.endsAt - now
	local model: Model = ctx.data.train
	if ctx.data.state == "Arriving" and elapsed >= Tren.ARRIVE then
		ctx.data.state = "Stopped"
		-- schimbarea roților: roțile coboară și urcă înapoi
		for _, wheel in model:GetChildren() do
			if wheel.Name == "Roata" and wheel:IsA("BasePart") then
				local base = wheel.CFrame
				task.spawn(function()
					wheel.CFrame = base - Vector3.new(0, 1.5, 0)
					task.wait(6)
					if wheel.Parent then
						wheel.CFrame = base
					end
				end)
			end
		end
	elseif ctx.data.state == "Stopped" and left <= Tren.LEAVE then
		ctx.data.state = "Leaving"
		Kit.glide(model, trainAt(ctx, stationX(ctx) + 520), Tren.LEAVE)
	end
	-- pe linie, cât merge trenul: cine e prins amețește
	if ctx.data.state ~= "Stopped" then
		local front = model:GetPivot().Position
		for _, owner in ctx.owners() do
			local root = Kit.root(owner)
			if root then
				local dz = math.abs(root.Position.Z - Village.railwayZ)
				local dx = root.Position.X - front.X
				if dz <= LINE_HIT and dx > -48 and dx < 10 then
					Kit.slow(owner, "train", 0, 1.5)
				end
			end
		end
	end
end

function Tren.stop(_ctx: any): { [any]: number }
	return {}
end

return Tren
