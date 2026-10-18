--!strict
-- Rutiera aduce un negustor: coboară la centru cu 3 semințe rare (Rare sau Epic), la 60% din preț. Primii 3
-- jucători ajunși la el își pot lua câte una (acțiunea { buy = seedId }, la cel mult 10 studs de negustor).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Kit = require(script.Parent.Kit)
local ShopService = require(script.Parent.Parent.Services.ShopService)

local Negustor = {}

Negustor.DISCOUNT = 0.6
Negustor.BUYERS = 3
Negustor.REACH = 10

function Negustor.start(ctx: any)
	local rng = Random.new()
	local pool = {}
	for _, creature in Creatures.list do
		if (creature.rarity == "Rare" or creature.rarity == "Epic") and creature.seedPrice then
			table.insert(pool, creature.id)
		end
	end
	local offers = {}
	while #offers < 3 and #pool > 0 do
		local id = table.remove(pool, rng:NextInteger(1, #pool)) :: string
		table.insert(
			offers,
			{ seedId = id, price = math.floor((Creatures.byId[id].seedPrice :: number) * Negustor.DISCOUNT) }
		)
	end
	local at = ctx.site * CFrame.new(10, 0, -16)
	local position = at.Position
	ctx.data.merchant = Kit.figure(
		"Negustor",
		CFrame.new(position.X, Kit.groundY(position.X, position.Z), position.Z) * at.Rotation,
		Color3.fromRGB(60, 70, 130),
		ctx.folder
	)
	ctx.data.offers = offers
	ctx.data.buyers = {}
	ctx.data.order = {}
	-- poziția reală a figurii (pe teren), nu cea a locului: clientul arată oferta după ea
	ctx.publish({ offers = offers, merchant = ctx.data.merchant:GetPivot().Position })
end

-- Pentru teste: oferta curentă
function Negustor.offers(ctx: any): { { seedId: string, price: number } }
	return ctx.data.offers
end

function Negustor.action(ctx: any, owner: any, payload: any)
	if typeof(payload) ~= "table" or typeof(payload.buy) ~= "string" then
		return
	end
	if ctx.data.buyers[owner] or #ctx.data.order >= Negustor.BUYERS then
		return
	end
	local root = Kit.root(owner)
	local merchant: Model = ctx.data.merchant
	local offset = root and root.Position - merchant:GetPivot().Position
	if not offset or Vector3.new(offset.X, 0, offset.Z).Magnitude > Negustor.REACH then
		return
	end
	for _, offer in ctx.data.offers do
		if offer.seedId == payload.buy then
			if ShopService.offer(owner, offer.seedId, offer.price) then
				ctx.data.buyers[owner] = true
				table.insert(ctx.data.order, owner)
				ctx.participate(owner)
				ctx.publish({
					offers = ctx.data.offers,
					merchant = merchant:GetPivot().Position,
					left = Negustor.BUYERS - #ctx.data.order,
				})
				if #ctx.data.order >= Negustor.BUYERS then
					ctx.finish()
				end
			end
			return
		end
	end
end

function Negustor.stop(ctx: any): { [any]: number }
	local placements = {}
	for _, owner in ctx.data.order do
		placements[owner] = 0 -- cumpărarea e răsplata; participarea se plătește oricum
	end
	return placements
end

return Negustor
