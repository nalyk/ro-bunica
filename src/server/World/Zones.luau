--!strict
-- Zonele satului (piese invizibile cu tag): „NoFight” e centrul, unde nu se aruncă cu papucul și unde cine nu
-- cară o creatură furată e la adăpost (un hoț cu creatura în brațe rămâne lovibil: centrul nu e ascunzătoare).

local CollectionService = game:GetService("CollectionService")

local Zones = {}

Zones.NO_FIGHT = "NoFight"

-- Marchează piesa ca zonă fără bătaie (forma: cutie sau cilindru vertical, după Shape)
function Zones.markNoFight(part: BasePart)
	part:SetAttribute(Zones.NO_FIGHT, true)
	CollectionService:AddTag(part, Zones.NO_FIGHT)
end

local function inside(part: BasePart, position: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	if part:IsA("Part") and part.Shape == Enum.PartType.Cylinder then
		-- cilindrul Roblox are axa pe X local: înălțimea e Size.X, raza Size.Y/2
		return math.abs(p.X) <= half.X and math.sqrt(p.Y * p.Y + p.Z * p.Z) <= half.Y
	end
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

function Zones.noFight(position: Vector3): boolean
	for _, part in CollectionService:GetTagged(Zones.NO_FIGHT) do
		if part:IsA("BasePart") and inside(part, position) then
			return true
		end
	end
	return false
end

return Zones
