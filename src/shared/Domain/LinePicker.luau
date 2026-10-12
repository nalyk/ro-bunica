--!strict
-- Alege o replică la întâmplare, fără să o repete pe ultima spusă.

local LinePicker = {}

function LinePicker.pick(lines: { string }, last: string?, rng: () -> number): string?
	if #lines == 0 then
		return nil
	end
	if #lines == 1 then
		return lines[1]
	end
	local candidates = {}
	for _, line in lines do
		if line ~= last then
			table.insert(candidates, line)
		end
	end
	local index = math.clamp(math.floor(rng() * #candidates) + 1, 1, #candidates)
	return candidates[index]
end

return LinePicker
