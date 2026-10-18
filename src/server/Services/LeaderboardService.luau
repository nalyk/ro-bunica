--!strict
-- Clasamentele săptămânale ale tuturor serverelor (OrderedDataStore, câte unul pe săptămână ISO):
-- „Papucul săptămânii” (apărări) și „Hora săptămânii” (hore dansate). Fiecare server adună în memorie
-- și scrie la un minut; topul 10 se citește la două minute și ajunge la clienți prin atributul „TopWeek”
-- (JSON) de pe ReplicatedStorage, afișat pe avizierul din centru. Fără DataStore (Studio, teste), nimic.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Week = require(Shared.Domain.Week)
local Progress = require(script.Parent.Parent.Progress)

local LeaderboardService = {}

LeaderboardService.STATS = { papuc = "defend", hora = "hora" } :: { [string]: string }
local FLUSH = 60
local REFRESH = 120
local TOP = 10

local pending: { [string]: { [number]: number } } = {}
local names: { [number]: string } = {}

local function store(stat: string, week: string?): OrderedDataStore?
	local ok, result = pcall(
		DataStoreService.GetOrderedDataStore,
		DataStoreService,
		"Top_" .. stat .. "_" .. (week or Week.key(os.time()))
	)
	return if ok then result else nil
end

function LeaderboardService.add(userId: number, stat: string, amount: number)
	if userId <= 0 or not LeaderboardService.STATS[stat] then
		return
	end
	local map = pending[stat] or {}
	pending[stat] = map
	map[userId] = (map[userId] or 0) + amount
end

-- `week`: doar pentru teste (o săptămână separată de cea reală)
function LeaderboardService.flush(week: string?)
	local batch = pending
	pending = {}
	for stat, map in batch do
		local target = store(stat, week)
		for userId, delta in map do
			local ok = target
				and pcall(target.UpdateAsync, target, tostring(userId), function(old: number?)
					return (old or 0) + delta
				end)
			if not ok then -- reîncercăm la următorul flush
				LeaderboardService.add(userId, stat, delta)
			end
		end
	end
end

local function nameOf(userId: number): string
	if not names[userId] then
		local player = Players:GetPlayerByUserId(userId)
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		names[userId] = if player then player.DisplayName elseif ok then name else "?"
	end
	return names[userId]
end

-- Topul săptămânii curente pentru o statistică: { {nume, valoare}, ... }
function LeaderboardService.top(stat: string, week: string?): { { any } }
	local list = {}
	local source = store(stat, week)
	if not source then
		return list
	end
	local ok, pages = pcall(source.GetSortedAsync, source, false, TOP)
	if not ok or not pages then
		return list
	end
	local okPage, page = pcall((pages :: any).GetCurrentPage, pages)
	if okPage and type(page) == "table" then
		for _, entry in page do
			table.insert(list, { nameOf(tonumber(entry.key) or 0), entry.value })
		end
	end
	return list
end

function LeaderboardService.refresh()
	local board: { [string]: any } = { week = Week.key(os.time()) }
	for stat in LeaderboardService.STATS do
		board[stat] = LeaderboardService.top(stat)
	end
	ReplicatedStorage:SetAttribute("TopWeek", HttpService:JSONEncode(board))
end

function LeaderboardService.start()
	Progress.on(function(owner, kind, amount)
		for stat, event in LeaderboardService.STATS do
			if kind == event and owner.player then
				LeaderboardService.add(owner.userId, stat, amount)
			end
		end
	end)
	task.spawn(function()
		LeaderboardService.refresh()
		local sinceRefresh = 0
		while true do
			task.wait(FLUSH)
			LeaderboardService.flush()
			sinceRefresh += FLUSH
			if sinceRefresh >= REFRESH then
				sinceRefresh = 0
				LeaderboardService.refresh()
			end
		end
	end)
	game:BindToClose(function()
		LeaderboardService.flush()
	end)
end

return LeaderboardService
