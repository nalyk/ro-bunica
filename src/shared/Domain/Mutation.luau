--!strict
-- Reguli de mutație: o singură mutație, una mai bună o înlocuiește pe una mai slabă.

local Mutations = require(script.Parent.Parent.Config.Mutations)

local Mutation = {}

-- Întoarce mutația rezultată după ce `incoming` încearcă să o înlocuiască pe `current`.
function Mutation.combine(current: string?, incoming: string): string?
	local incomingDef = Mutations.byId[incoming]
	if not incomingDef then
		return current
	end
	if current == nil then
		return incoming
	end
	local currentDef = Mutations.byId[current]
	if not currentDef or incomingDef.rank > currentDef.rank then
		return incoming
	end
	return current
end

-- Încearcă o mutație cu o șansă dată. Întoarce noua mutație și dacă s-a schimbat ceva.
function Mutation.tryApply(
	current: string?,
	incoming: string,
	chance: number,
	rng: () -> number
): (string?, boolean)
	if rng() >= chance then
		return current, false
	end
	local result = Mutation.combine(current, incoming)
	return result, result ~= current
end

return Mutation
