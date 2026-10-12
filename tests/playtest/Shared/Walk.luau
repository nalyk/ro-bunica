--!strict
-- Mers cu pathfinding pentru playtest: îl folosesc atât clientul (jucătorul real), cât și botul de pe server.
-- Replanifică de la poziția curentă când personajul nu mai înaintează și are un buget total de timp.

local PathfindingService = game:GetService("PathfindingService")

local Walk = {}

local STEP_TIMEOUT = 2
local TOTAL_BUDGET = 40
local MAX_PLANS = 4

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function moveTo(humanoid: Humanoid, position: Vector3): boolean
	humanoid:MoveTo(position)
	local reached = false
	local connection = humanoid.MoveToFinished:Connect(function(ok)
		reached = ok
	end)
	local deadline = os.clock() + STEP_TIMEOUT
	while not reached and os.clock() < deadline do
		task.wait(0.05)
	end
	connection:Disconnect()
	return reached
end

-- Merge până aproape de țintă. Întoarce distanța orizontală rămasă.
function Walk.to(character: Model, target: Vector3, tolerance: number?): number
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local limit = tolerance or 3
	local started = os.clock()
	for attempt = 1, MAX_PLANS do
		if flatDistance(root.Position, target) <= limit or os.clock() - started > TOTAL_BUDGET then
			break
		end
		local path = PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = true,
			WaypointSpacing = 6,
		})
		local ok = pcall(function()
			path:ComputeAsync(root.Position, target)
		end)
		local waypoints = if ok and path.Status == Enum.PathStatus.Success then path:GetWaypoints() else {}
		print(
			string.format(
				"[PLAYTEST] walk %s plan %d: %s, %d puncte, %.0f studs",
				character.Name,
				attempt,
				if ok then path.Status.Name else "eroare",
				#waypoints,
				flatDistance(root.Position, target)
			)
		)
		if #waypoints == 0 then
			moveTo(humanoid, target)
			continue
		end
		local stuck = 0
		for index = 2, #waypoints do
			local waypoint = waypoints[index]
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end
			if moveTo(humanoid, waypoint.Position) then
				stuck = 0
			else
				stuck += 1
				if stuck >= 2 or os.clock() - started > TOTAL_BUDGET then
					break -- replanifică de unde a rămas
				end
			end
		end
	end
	if flatDistance(root.Position, target) > limit then
		moveTo(humanoid, target)
	end
	return flatDistance(root.Position, target)
end

return Walk
