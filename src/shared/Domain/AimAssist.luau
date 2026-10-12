--!strict
-- Ajutor la ochit: dacă jucătorul aruncă aproape de o țintă, papucul pleacă spre țintă.
-- Distanța se măsoară pe orizontală (pe telefon, înălțimea punctului atins e imprecisă).

local AimAssist = {}

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Întoarce ținta cea mai apropiată de punctul ochit, dacă e în rază; altfel punctul ochit.
function AimAssist.retarget(aim: Vector3, targets: { Vector3 }, radius: number): Vector3
	local best: Vector3? = nil
	local bestDistance = radius
	for _, target in targets do
		local distance = flatDistance(aim, target)
		if distance <= bestDistance then
			best, bestDistance = target, distance
		end
	end
	return best or aim
end

return AimAssist
