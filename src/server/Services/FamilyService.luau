--!strict
-- Familiile: prietenii Roblox de pe server (maximum 4). Membrii nu-și fură între ei,
-- își apără ogrăzile reciproc cu papucul, iar Bunica îi consideră „ai casei”.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Families = require(Shared.Config.Families)
local Family = require(Shared.Domain.Family)
local PlotService = require(script.Parent.PlotService)
local Actors = require(script.Parent.Parent.Actors)
local Friends = require(script.Parent.Parent.Social.Friends)

type Owner = PlotService.Owner
type Actor = Actors.Actor

local FamilyService = {}

local familyOf: { [Actor]: number } = {}
local overrides: { [Actor]: number } = {} -- boți din teste
local joinOrder: { Player } = {}

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
		player:SetAttribute("FamilyId", familyOf[Actors.forPlayer(player)])
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
		return Friends.areFriends(byId[a], byId[b])
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
