--!strict
-- Familiile: prietenii Roblox de pe server (maximum 4), plus cei din același grup Roblox (party) și cei
-- veniți prin link-ul ogrăzii cuiva (LaunchService.bond, pe sesiune). Membrii nu-și fură între ei,
-- își apără ogrăzile reciproc cu papucul, iar Bunica îi consideră „ai casei”.
-- Familia e o alegere: doi prieteni sunt familie doar dacă amândoi au modul „Family”; unul pe „Rival”
-- îi face rivali (se pot fura, ca străinii). Modul se schimbă doar ziua.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Families = require(Shared.Config.Families)
local Family = require(Shared.Domain.Family)
local RateLimiter = require(Shared.Domain.RateLimiter)
local PlotService = require(script.Parent.PlotService)
local Actors = require(script.Parent.Parent.Actors)
local Friends = require(script.Parent.Parent.Social.Friends)
local DayNightService = require(script.Parent.DayNightService)
local Messenger = require(script.Parent.Messenger)
local Analytics = require(script.Parent.Parent.Analytics)
local Net = require(Shared.Net)

local SWITCH_COOLDOWN = 10
local switchLimiter = RateLimiter.new(3, 0.2)

type Owner = PlotService.Owner
type Actor = Actors.Actor

local FamilyService = {}

local familyOf: { [Actor]: number } = {}
local overrides: { [Actor]: number } = {} -- boți din teste
local joinOrder: { Player } = {}
local lastSwitch: { [Player]: number } = {}
local greetedPairs: { [string]: boolean } = {} -- prietenii anunțați deja unul despre altul (o dată pe sesiune)
local bonds: { [string]: boolean } = {} -- perechi legate pe sesiune (gazda și cel venit prin link-ul ei)

local function pairKey(a: number, b: number): string
	return math.min(a, b) .. ":" .. math.max(a, b)
end

-- Același grup Roblox (party): „PartyId” gol înseamnă fără grup
local function sameParty(a: Player, b: Player): boolean
	local ok, partyA = pcall(function()
		return (a :: any).PartyId
	end)
	local okB, partyB = pcall(function()
		return (b :: any).PartyId
	end)
	return ok and okB and type(partyA) == "string" and partyA ~= "" and partyA == partyB
end

-- Cei doi pot fi familie: prieteni, același grup sau legați prin link
local function close(a: Player, b: Player): boolean
	return bonds[pairKey(a.UserId, b.UserId)] == true or sameParty(a, b) or Friends.areFriends(a, b)
end

local function modeOf(player: Player): string?
	local owner = PlotService.getOwner(player)
	return if owner then owner.profile.familyMode else nil
end

local function applyAttributes()
	for _, plot in PlotService.plots do
		local owner = plot.owner
		local id = if owner and owner.actor then familyOf[owner.actor] else nil
		plot.geometry.model:SetAttribute("FamilyId", id)
		-- Tăblița ogrăzii ia culoarea familiei
		local color = if id then Families.colors[(id % #Families.colors) + 1] else Color3.fromRGB(200, 30, 40)
		plot.geometry.sign.TextColor3 = color
	end
	for _, player in Players:GetPlayers() do
		local id = familyOf[Actors.forPlayer(player)]
		if id ~= nil then
			Analytics.social(player, "FamilyFormed")
		end
		player:SetAttribute("FamilyId", id)
		player:SetAttribute("FamilyMode", modeOf(player) or "Family")
	end
end

-- Prietenii de pe server află că pot alege: familie sau rivali (o dată pe pereche și sesiune)
local function greetFriends(present: { number }, byId: { [number]: Player })
	local hasFriend: { [Player]: boolean } = {}
	for i, a in present do
		for j = i + 1, #present do
			local b = present[j]
			local playerA, playerB = byId[a], byId[b]
			if close(playerA, playerB) then
				hasFriend[playerA] = true
				hasFriend[playerB] = true
				local key = pairKey(a, b)
				if not greetedPairs[key] then
					greetedPairs[key] = true
					Messenger.notify(playerA, "notify.FriendHere", { playerB.DisplayName })
					Messenger.notify(playerB, "notify.FriendHere", { playerA.DisplayName })
				end
			end
		end
	end
	for _, player in Players:GetPlayers() do
		player:SetAttribute("HasFriendHere", hasFriend[player] == true)
	end
end

function FamilyService.recompute()
	local present = {}
	local byId: { [number]: Player } = {}
	for _, player in joinOrder do
		if player.Parent == Players and PlotService.getOwner(player) then
			table.insert(present, player.UserId)
			byId[player.UserId] = player
		end
	end
	local groups = Family.group(present, function(a, b)
		return close(byId[a], byId[b]) and Family.bonded(modeOf(byId[a]), modeOf(byId[b]))
	end, Families.maxSize)
	table.clear(familyOf)
	for userId, familyId in groups do
		familyOf[Actors.forPlayer(byId[userId])] = familyId
	end
	for actor, familyId in overrides do
		if actor.alive then
			familyOf[actor] = familyId
		end
	end
	applyAttributes()
	greetFriends(present, byId)
end

-- Schimbă modul jucătorului („Family” sau „Rival”); doar ziua. Întoarce dacă s-a schimbat.
function FamilyService.setMode(player: Player, mode: unknown): boolean
	local owner = PlotService.getOwner(player)
	if not owner or (mode ~= "Family" and mode ~= "Rival") then
		return false
	end
	local now = Workspace:GetServerTimeNow()
	if not Family.canSwitch(DayNightService.phase(), lastSwitch[player], now, SWITCH_COOLDOWN) then
		Messenger.notify(player, "notify.FamilyModeDayOnly")
		return false
	end
	if owner.profile.familyMode == mode then
		return false
	end
	lastSwitch[player] = now
	owner.profile.familyMode = mode :: string
	FamilyService.recompute()
	Messenger.notify(player, if mode == "Rival" then "notify.NowRival" else "notify.NowFamily")
	return true
end

function FamilyService.familyId(actor: Actor): number?
	return familyOf[actor]
end

function FamilyService.sameFamily(a: Actor?, b: Actor?): boolean
	if not a or not b or a == b then
		return false
	end
	local id = familyOf[a]
	return id ~= nil and id == familyOf[b]
end

-- Ogrăzile pe care le apără un proprietar: a lui și ale familiei.
function FamilyService.familyOwners(owner: Owner): { Owner }
	local list = { owner }
	local id = if owner.actor then familyOf[owner.actor] else nil
	if id then
		for _, other in PlotService.owners() do
			if other ~= owner and other.actor and familyOf[other.actor] == id then
				table.insert(list, other)
			end
		end
	end
	return list
end

-- Leagă doi jucători pe sesiunea asta (cel venit prin link-ul ogrăzii celuilalt), apoi refă familiile
function FamilyService.bond(a: Player, b: Player)
	if a ~= b then
		bonds[pairKey(a.UserId, b.UserId)] = true
		FamilyService.recompute()
	end
end

-- Pentru teste (boți): pune un actor într-o familie.
function FamilyService.setFamily(actor: Actor, familyId: number?)
	if familyId then
		overrides[actor] = familyId
	else
		overrides[actor] = nil
	end
	FamilyService.recompute()
end

function FamilyService.start()
	Players.PlayerAdded:Connect(function(player)
		table.insert(joinOrder, player)
	end)
	for _, player in Players:GetPlayers() do
		table.insert(joinOrder, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local index = table.find(joinOrder, player)
		if index then
			table.remove(joinOrder, index)
		end
		lastSwitch[player] = nil
	end)
	Net.get("FamilyMode").OnServerEvent:Connect(function(player, mode)
		if switchLimiter:allow(player.UserId, os.clock()) then
			FamilyService.setMode(player, mode)
		end
	end)
	PlotService.onOwnerAdded(function()
		task.spawn(FamilyService.recompute)
	end)
	PlotService.onOwnerRemoving(function()
		task.defer(FamilyService.recompute)
	end)
	Actors.onRemoving(function(actor)
		overrides[actor] = nil
		familyOf[actor] = nil
	end)
end

return FamilyService
