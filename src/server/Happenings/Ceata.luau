--!strict
-- Ceața (noaptea): 60 de secunde în care nu vezi departe. Bunicile NPC văd la jumătate din distanță, deci e
-- momentul hoților (și al celor care își păzesc singuri ograda). Răsplata e pentru cine iese din curte.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameState = require(Shared.GameState)
local Kit = require(script.Parent.Kit)
local BunicaService = require(script.Parent.Parent.Services.BunicaService)

local Ceata = {}

Ceata.SIGHT = 0.5

function Ceata.start(ctx: any)
	ctx.data.previousSight = BunicaService.sight()
	BunicaService.setSight(Ceata.SIGHT)
	GameState.set(GameState.Attributes.Fog, 1)
end

function Ceata.tick(ctx: any, _dt: number)
	-- participă cine iese din ogradă în ceață (hoț sau paznic pe uliță)
	for _, owner in ctx.owners() do
		local root = Kit.root(owner)
		if root and owner.plot and owner.plot.geometry then
			local localPos = owner.plot.geometry.cframe:PointToObjectSpace(root.Position)
			if math.abs(localPos.X) > 42 or math.abs(localPos.Z) > 37 then
				ctx.participate(owner)
			end
		end
	end
end

function Ceata.stop(ctx: any): { [any]: number }
	BunicaService.setSight(ctx.data.previousSight or 1)
	GameState.set(GameState.Attributes.Fog, 0)
	return {}
end

return Ceata
