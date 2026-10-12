--!strict
-- Ritualul Horei: destui dansatori în cerc, neîntrerupt, un timp dat.

export type Dancer = { id: number, position: Vector3 }
export type State = { since: number? }
export type Config = { center: Vector3, radius: number, minDancers: number, holdSeconds: number }

local Ritual = {}

function Ritual.inCircle(dancers: { Dancer }, center: Vector3, radius: number): { number }
	local ids = {}
	for _, dancer in dancers do
		local flat = Vector3.new(dancer.position.X - center.X, 0, dancer.position.Z - center.Z)
		if flat.Magnitude <= radius then
			table.insert(ids, dancer.id)
		end
	end
	return ids
end

-- Actualizează starea. Întoarce (true, participanți) în momentul în care ritualul se împlinește.
function Ritual.update(state: State, dancers: { Dancer }, now: number, config: Config): (boolean, { number })
	local inside = Ritual.inCircle(dancers, config.center, config.radius)
	if #inside < config.minDancers then
		state.since = nil
		return false, inside
	end
	if state.since == nil then
		state.since = now
	end
	if now - (state.since :: number) >= config.holdSeconds then
		state.since = nil
		return true, inside
	end
	return false, inside
end

return Ritual
