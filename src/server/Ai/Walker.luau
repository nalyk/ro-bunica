--!strict
-- Mers simplu pentru boți: segmente drepte cu Humanoid:MoveTo și timeout pe fiecare punct.
-- Traseele din sat (drum → poartă → ogradă) sunt deschise, deci nu e nevoie de pathfinding.

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

return Walker
