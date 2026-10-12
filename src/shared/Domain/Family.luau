--!strict
-- Familii din graful de prietenie: componente conexe (BFS), împărțite în grupuri de cel mult `maxSize`.

local Family = {}

-- Întoarce id → familyId (id-ul primului membru din grup). `ids` dă ordinea (de obicei ordinea intrării).
function Family.group(
	ids: { number },
	areFriends: (number, number) -> boolean,
	maxSize: number
): { [number]: number }
	local result: { [number]: number } = {}
	local visited: { [number]: boolean } = {}
	for _, start in ids do
		if visited[start] then
			continue
		end
		-- Componenta conexă, în ordinea BFS
		local order = {}
		local queue = { start }
		visited[start] = true
		while #queue > 0 do
			local current = table.remove(queue, 1) :: number
			table.insert(order, current)
			for _, other in ids do
				if not visited[other] and areFriends(current, other) then
					visited[other] = true
					table.insert(queue, other)
				end
			end
		end
		-- Grupuri de cel mult maxSize; un singur membru nu formează familie
		for index = 1, #order, maxSize do
			local leader = order[index]
			local size = math.min(maxSize, #order - index + 1)
			if size >= 2 then
				for offset = 0, size - 1 do
					result[order[index + offset]] = leader
				end
			end
		end
	end
	return result
end

-- Alege ograda liberă cea mai apropiată de ogrăzile prietenilor (sau prima liberă, dacă nu are prieteni).
function Family.choosePlot(free: { Vector3 }, friends: { Vector3 }): number?
	if #free == 0 then
		return nil
	end
	if #friends == 0 then
		return 1
	end
	local best, bestDistance = 1, math.huge
	for index, position in free do
		for _, friend in friends do
			local distance = (position - friend).Magnitude
			if distance < bestDistance then
				best, bestDistance = index, distance
			end
		end
	end
	return best
end

return Family
