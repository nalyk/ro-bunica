--!strict
-- Prietenia Roblox între jucători, cu cache (IsFriendsWithAsync face o cerere web).

local Friends = {}

local cache: { [string]: boolean } = {}

local function pairKey(a: number, b: number): string
	return math.min(a, b) .. ":" .. math.max(a, b)
end

function Friends.areFriends(a: Player, b: Player): boolean
	if a == b then
		return false
	end
	local key = pairKey(a.UserId, b.UserId)
	local cached = cache[key]
	if cached ~= nil then
		return cached
	end
	local ok, result = pcall(function()
		return a:IsFriendsWithAsync(b.UserId)
	end)
	local value = ok and result == true
	cache[key] = value
	return value
end

-- Pentru teste: declară doi jucători prieteni fără cererea web.
function Friends.set(a: number, b: number, value: boolean)
	cache[pairKey(a, b)] = value
end

return Friends
