--!strict
-- Pe ce server e fiecare jucător (MemoryStore, hash map cu expirare): cine vine dintr-un link
-- „vino în ograda mea” ajunge pe serverul gazdei. Totul în pcall: fără MemoryStore (Studio, teste),
-- jocul merge mai departe, doar fără mutarea pe serverul gazdei.

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")

local Presence = {}

local TTL = 150
local REFRESH = 60

local map: MemoryStoreHashMap? = nil
local function store(): MemoryStoreHashMap?
	if not map then
		local ok, result = pcall(MemoryStoreService.GetHashMap, MemoryStoreService, "Presence")
		map = if ok then result else nil
	end
	return map
end

local function write(player: Player)
	local hash = store()
	if hash then
		pcall(hash.SetAsync, hash, tostring(player.UserId), game.JobId, TTL)
	end
end

-- Serverul (JobId) pe care e acum jucătorul; nil dacă nu se știe
function Presence.jobOf(userId: number): string?
	local hash = store()
	if not hash then
		return nil
	end
	local ok, value = pcall(hash.GetAsync, hash, tostring(userId))
	return if ok and type(value) == "string" and value ~= "" then value else nil
end

function Presence.start()
	if game.JobId == "" then
		return -- Studio: fără servere de găsit
	end
	Players.PlayerAdded:Connect(write)
	for _, player in Players:GetPlayers() do
		write(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local hash = store()
		if hash then
			pcall(hash.RemoveAsync, hash, tostring(player.UserId))
		end
	end)
	task.spawn(function()
		while true do
			task.wait(REFRESH)
			for _, player in Players:GetPlayers() do
				write(player)
			end
		end
	end)
end

return Presence
