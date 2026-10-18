--!strict
-- Lupii la stână (noaptea, co-op contra serverului): 6 lupi (3 dacă ești singur) ies din codru spre țarcul
-- oilor. Doi papuci gonesc un lup. Dacă 3 lupi ajung în țarc, oile fug: rămâne doar răsplata de participare.
-- Altfel, 300 de lei se împart după lovituri (Domain/Wolves).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Wolves = require(Shared.Domain.Wolves)
local Kit = require(script.Parent.Kit)
local WolfAi = require(script.Parent.Parent.Ai.WolfAi)
local PlotService = require(script.Parent.Parent.Services.PlotService)
local SlipperService = require(script.Parent.Parent.Services.SlipperService)

local Lupi = {}

local SPEED = 5.5
local FLEE_SPEED = 14
local PEN_REACH = 9
local SPAWN_GAP = 4 -- secunde între lupi

local function marker(site: string, name: string, fallback: Vector3): Vector3
	local sites = workspace:FindFirstChild("Village") and workspace.Village:FindFirstChild("Sites")
	local holder = sites and sites:FindFirstChild(site)
	local part = holder and holder:FindFirstChild(name, true)
	return if part and part:IsA("BasePart") then part.Position else fallback
end

function Lupi.start(ctx: any)
	local sites = Kit.layout.sites
	ctx.data.forest = marker("codru", "Iesire", sites.codru.Position)
	ctx.data.pen = marker("stana", "TarcZona", sites.stana.Position)
	ctx.data.total = Wolves.count(#ctx.owners())
	ctx.data.spawned = 0
	ctx.data.nextSpawn = 0
	ctx.data.wolves = {}
	ctx.data.inPen = 0
	ctx.data.hits = {}
	ctx.data.order = {}
	ctx.data.failed = false
end

-- Pentru teste
function Lupi.wolves(ctx: any): { WolfAi.Wolf }
	return ctx.data.wolves
end

local function onHit(ctx: any, wolf: WolfAi.Wolf, thrower: any)
	if wolf.state == "Fleeing" or wolf.state == "Gone" or wolf.state == "InPen" then
		return
	end
	wolf.hits += 1
	local owner = thrower and PlotService.getOwnerOfActor(thrower)
	if owner then
		ctx.participate(owner)
		ctx.data.hits[owner] = (ctx.data.hits[owner] or 0) + 1
		if not table.find(ctx.data.order, owner) then
			table.insert(ctx.data.order, owner)
		end
	end
	if wolf.hits >= Wolves.HITS_TO_SCARE then
		wolf.state = "Fleeing"
		SlipperService.unregisterTarget(wolf.model)
	else
		wolf.state = "Stunned"
		wolf.stunnedUntil = os.clock() + 1.2
	end
end

function Lupi.tick(ctx: any, dt: number)
	local now = os.clock()
	if ctx.data.spawned < ctx.data.total and now >= ctx.data.nextSpawn then
		ctx.data.spawned += 1
		ctx.data.nextSpawn = now + SPAWN_GAP
		local offset = Vector3.new((ctx.data.spawned - 3.5) * 5, 0, 0)
		local wolf = WolfAi.create(ctx.data.forest + offset, ctx.folder)
		table.insert(ctx.data.wolves, wolf)
		SlipperService.registerTarget(wolf.model, function(thrower)
			onHit(ctx, wolf, thrower)
		end, 3)
	end
	local active = 0
	for _, wolf in ctx.data.wolves :: { WolfAi.Wolf } do
		if wolf.state == "Coming" then
			active += 1
			if WolfAi.step(wolf, ctx.data.pen, SPEED, dt) <= PEN_REACH then
				wolf.state = "InPen"
				SlipperService.unregisterTarget(wolf.model)
				ctx.data.inPen += 1
			end
		elseif wolf.state == "Stunned" then
			active += 1
			if now >= wolf.stunnedUntil then
				wolf.state = "Coming"
			end
		elseif wolf.state == "Fleeing" then
			if WolfAi.step(wolf, ctx.data.forest, FLEE_SPEED, dt) <= 2 then
				wolf.state = "Gone"
				wolf.model:Destroy()
			end
		end
	end
	if Wolves.failed(ctx.data.inPen) then
		ctx.data.failed = true
		ctx.finish()
	elseif ctx.data.spawned >= ctx.data.total and active == 0 then
		ctx.finish() -- toți lupii goniți sau ajunși (sub prag): oile au rămas
	end
end

function Lupi.stop(ctx: any): { [any]: number }
	for _, wolf in ctx.data.wolves :: { WolfAi.Wolf } do
		SlipperService.unregisterTarget(wolf.model)
	end
	if ctx.data.failed then
		return {} -- oile au fugit: doar participarea
	end
	for owner, lei in Wolves.split(ctx.data.hits, Wolves.POOL) do
		ctx.give(owner, lei)
	end
	return Kit.placements(ctx.data.hits, ctx.data.order)
end

return Lupi
