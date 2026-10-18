--!strict
-- Alarma în lanț: când un hoț care cară o creatură trece pe lângă alte ogrăzi, câinii lor latră și
-- proprietarii primesc o alarmă discretă. O ogradă e anunțată o dată pe hoț, apoi după o pauză.

export type State = { heard: { [string]: number } } -- "hoț:ogradă" → momentul

local ChainAlarm = {}

ChainAlarm.RADIUS = 30 -- de la poarta ogrăzii
ChainAlarm.COOLDOWN = 20

function ChainAlarm.new(): State
	return { heard = {} }
end

-- Ogrăzile (indexuri) care trebuie anunțate acum. `victim` e ograda prădată (ea știe deja).
function ChainAlarm.update(
	state: State,
	thief: string,
	position: Vector3,
	gates: { Vector3 },
	victim: number?,
	now: number
): { number }
	local list = {}
	for index, gate in gates do
		if index ~= victim then
			local d = Vector3.new(position.X - gate.X, 0, position.Z - gate.Z).Magnitude
			if d <= ChainAlarm.RADIUS then
				local key = thief .. ":" .. index
				local last = state.heard[key]
				if not last or now - last > ChainAlarm.COOLDOWN then
					state.heard[key] = now
					table.insert(list, index)
				end
			end
		end
	end
	return list
end

return ChainAlarm
