--!strict
-- Ținta aleasă pe hartă: sosirea (pe orizontală) și poteca de puncte cusute de pe pământ, la pas egal pe
-- drumul calculat (PathfindingService), doar pe bucata din fața jucătorului.

local Waypoint = {}

function Waypoint.arrived(position: Vector3, target: Vector3, radius: number): boolean
	return Vector3.new(target.X - position.X, 0, target.Z - position.Z).Magnitude <= radius
end

-- Puncte la `spacing` studs de-a lungul liniei frânte, de la început până la `maxLength`
function Waypoint.trail(points: { Vector3 }, spacing: number, maxLength: number): { Vector3 }
	local out: { Vector3 } = {}
	if #points < 2 then
		return out
	end
	local travelled = 0
	local nextAt = 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local length = (b - a).Magnitude
		while length > 0 and nextAt <= travelled + length and nextAt <= maxLength do
			table.insert(out, a:Lerp(b, (nextAt - travelled) / length))
			nextAt += spacing
		end
		travelled += length
		if travelled >= maxLength then
			break
		end
	end
	return out
end

return Waypoint
