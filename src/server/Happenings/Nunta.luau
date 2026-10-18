--!strict
-- Trece o nuntă: cortegiul (mirele, mireasa, doi lăutari) merge pe drumul mare de la un capăt la altul. Cine
-- se prinde în hora din jurul lui (raza 10) dansează (muzica de horă pornește singură) și primește 1 leu pe
-- secundă, cel mult 60. Clienții primesc poziția cortegiului (confetti).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Village = require(Shared.Config.Village)
local VillageLayout = require(Shared.Domain.VillageLayout)
local Kit = require(script.Parent.Kit)
local Actors = require(script.Parent.Parent.Actors)
local HoraService = require(script.Parent.Parent.Services.HoraService)

local Nunta = {}

Nunta.RADIUS = 10
Nunta.MAX_SECONDS = 60
Nunta.LEI_PER_SECOND = 1

local MEMBERS = {
	{ name = "Mirele", shirt = Color3.fromRGB(40, 40, 50), offset = Vector3.new(-1.6, 0, 0) },
	{
		name = "Mireasa",
		shirt = Color3.fromRGB(250, 250, 250),
		offset = Vector3.new(1.6, 0, 0),
		scarf = Color3.fromRGB(255, 255, 255),
	},
	{ name = "Lautar1", shirt = Color3.fromRGB(150, 30, 40), offset = Vector3.new(-2.5, 0, 4) },
	{ name = "Lautar2", shirt = Color3.fromRGB(150, 30, 40), offset = Vector3.new(2.5, 0, 4) },
}

function Nunta.start(ctx: any)
	local members = {}
	local start = VillageLayout.lower(-Village.extent + 30)
	for _, def in MEMBERS do
		local at = start + def.offset
		table.insert(members, {
			model = Kit.figure(
				def.name,
				CFrame.new(at.X, Kit.groundY(at.X, at.Z), at.Z),
				def.shirt,
				ctx.folder,
				def.scarf
			),
			offset = def.offset,
		})
	end
	ctx.data.members = members
	ctx.data.seconds = {}
	ctx.data.order = {}
	ctx.data.progress = 0
end

-- Centrul cortegiului acum
function Nunta.center(ctx: any): Vector3
	local x = -Village.extent + 30 + (2 * (Village.extent - 30)) * ctx.data.progress
	local p = VillageLayout.lower(x)
	return Vector3.new(p.X, Kit.groundY(p.X, p.Z), p.Z)
end

function Nunta.tick(ctx: any, dt: number)
	local duration = ctx.endsAt - ctx.startedAt
	ctx.data.progress = math.clamp(ctx.data.progress + dt / duration, 0, 1)
	local center = Nunta.center(ctx)
	local ahead = VillageLayout.lower(
		-Village.extent + 30 + (2 * (Village.extent - 30)) * math.min(1, ctx.data.progress + 0.01)
	)
	local dir = Vector3.new(ahead.X - center.X, 0, ahead.Z - center.Z)
	local facing = if dir.Magnitude > 0.01 then CFrame.lookAt(center, center + dir) else CFrame.new(center)
	for i, member in ctx.data.members do
		local hop = math.abs(math.sin(os.clock() * 6 + i)) * 0.4
		local cf = facing * CFrame.new(member.offset) * CFrame.new(0, hop, 0)
		Kit.glide(member.model, cf, dt)
	end
	for _, owner in ctx.owners() do
		local root = Kit.root(owner)
		if
			root
			and Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z).Magnitude
				<= Nunta.RADIUS
		then
			local seconds = ctx.data.seconds[owner] or 0
			if seconds < Nunta.MAX_SECONDS then
				local before = math.floor(seconds)
				seconds = math.min(Nunta.MAX_SECONDS, seconds + dt)
				ctx.data.seconds[owner] = seconds
				local earned = math.floor(seconds) - before
				if earned > 0 then
					ctx.give(owner, earned * Nunta.LEI_PER_SECOND)
				end
			end
			if not table.find(ctx.data.order, owner) then
				table.insert(ctx.data.order, owner)
			end
			ctx.participate(owner)
			if owner.actor and Actors.root(owner.actor) then
				HoraService.setDancing(owner.actor, 1.5)
			end
		end
	end
	ctx.data.publishAt = ctx.data.publishAt or 0
	if os.clock() >= ctx.data.publishAt then
		ctx.data.publishAt = os.clock() + 1
		ctx.publish({ wedding = center })
	end
end

function Nunta.stop(ctx: any): { [any]: number }
	return Kit.placements(ctx.data.seconds, ctx.data.order)
end

return Nunta
