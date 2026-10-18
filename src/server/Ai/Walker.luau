--!strict
-- Mers pentru boți. `follow`: segmente drepte cu Humanoid:MoveTo și timeout pe fiecare punct (traseele scurte
-- și deschise ale hoțului din tutorial). `pathTo`: pathfinding pentru drumuri lungi prin sat (porți, fântâna din
-- vatră), cu replanificare când botul nu mai înaintează.

local PathfindingService = game:GetService("PathfindingService")

local Walker = {}

local DEFAULT_TIMEOUT = 6

function Walker.moveTo(humanoid: Humanoid, position: Vector3, timeout: number?): boolean
	if not humanoid.Parent then
		return false
	end
	humanoid:MoveTo(position)
	local reached = false
	local connection = humanoid.MoveToFinished:Connect(function(ok)
		reached = ok
	end)
	local deadline = os.clock() + (timeout or DEFAULT_TIMEOUT)
	while not reached and os.clock() < deadline and humanoid.Parent do
		task.wait(0.05)
	end
	connection:Disconnect()
	return reached
end

-- Parcurge punctele în ordine. `shouldStop` oprește mersul (de exemplu când botul e lovit).
function Walker.follow(humanoid: Humanoid, points: { Vector3 }, shouldStop: (() -> boolean)?)
	for _, point in points do
		if shouldStop and shouldStop() then
			return
		end
		Walker.moveTo(humanoid, point)
	end
end

local PATH_STEP_TIMEOUT = 2
local MAX_PLANS = 5

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Merge până aproape de țintă (`tolerance` studs pe orizontală), cât `shouldStop` nu cere oprirea.
-- Întoarce true dacă a ajuns.
function Walker.pathTo(
	humanoid: Humanoid,
	root: BasePart,
	target: Vector3,
	shouldStop: () -> boolean,
	tolerance: number?
): boolean
	local limit = tolerance or 3
	for _ = 1, MAX_PLANS do
		if flatDistance(root.Position, target) <= limit then
			return true
		end
		if shouldStop() or not humanoid.Parent then
			return false
		end
		-- raza 3: cu 2, drumul trece razant pe lângă colțurile ogrăzilor rotite (satul de vale) și NPC-ul se agață
		local path = PathfindingService:CreatePath({
			AgentRadius = 3,
			AgentHeight = 6,
			AgentCanJump = false,
			WaypointSpacing = 6,
		})
		local ok = pcall(function()
			path:ComputeAsync(root.Position, target)
		end)
		local waypoints = if ok and path.Status == Enum.PathStatus.Success then path:GetWaypoints() else {}
		if #waypoints == 0 then
			Walker.moveTo(humanoid, target, PATH_STEP_TIMEOUT)
			continue
		end
		local stuck = 0
		for index = 2, #waypoints do
			if shouldStop() or not humanoid.Parent then
				return false
			end
			if Walker.moveTo(humanoid, waypoints[index].Position, PATH_STEP_TIMEOUT) then
				stuck = 0
			else
				stuck += 1
				if stuck >= 2 then
					-- un pas înapoi, departe de obstacol, apoi replanifică de acolo
					local away = root.Position - waypoints[index].Position
					away = Vector3.new(away.X, 0, away.Z)
					if away.Magnitude > 0.1 then
						Walker.moveTo(humanoid, root.Position + away.Unit * 4, PATH_STEP_TIMEOUT)
					end
					break
				end
			end
		end
	end
	return flatDistance(root.Position, target) <= limit
end

return Walker
