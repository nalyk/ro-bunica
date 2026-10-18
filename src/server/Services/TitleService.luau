--!strict
-- Titlurile (Domain/Titles): statisticile se adună din evenimentele de progres; jucătorul își alege unul,
-- care apare deasupra numelui (atributul „Title” pe personaj, tradus pe client de TitleController).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Titles = require(Shared.Domain.Titles)
local Decor = require(Shared.Domain.Decor)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)
local Progress = require(script.Parent.Parent.Progress)

type Owner = PlotService.Owner

local TitleService = {}

-- Statisticile pentru titluri, din profil
function TitleService.stats(owner: Owner): { [string]: number }
	local profile = owner.profile
	local s = profile.stats :: any
	local collection = 0
	for _ in (profile.collection or {}) :: { [string]: boolean } do
		collection += 1
	end
	return {
		steals = s.steals or 0,
		defends = s.defends or 0,
		fish = s.fish or 0,
		hora = s.hora or 0,
		happenings = s.happenings or 0,
		minigames = s.minigames or 0,
		collection = collection,
		decor = Decor.placedCount(profile :: any),
	}
end

local function show(owner: Owner)
	local player = owner.player
	local character = player and player.Character
	if character then
		local id = owner.profile.title
		character:SetAttribute(
			"Title",
			if id and Titles.canUse(TitleService.stats(owner), id) then id else nil
		)
	end
end

function TitleService.set(owner: Owner, id: string?): boolean
	if id ~= nil and not Titles.canUse(TitleService.stats(owner), id) then
		return false
	end
	owner.profile.title = id
	show(owner)
	StateService.markDirty(owner.player)
	return true
end

function TitleService.start()
	Progress.on(function(owner, kind)
		local stats = owner and owner.profile and owner.profile.stats :: any
		if not stats then
			return
		end
		if kind == "fish" or kind == "hora" or kind == "happening" or kind == "minigame" then
			local field = if kind == "happening"
				then "happenings"
				elseif kind == "minigame" then "minigames"
				else kind
			stats[field] = (stats[field] or 0) + 1
			StateService.markDirty(owner.player)
		end
	end)
	Net.get("SetTitle").OnServerEvent:Connect(function(player, id)
		local owner = PlotService.getOwner(player)
		if owner and (id == nil or typeof(id) == "string") then
			TitleService.set(owner, id)
		end
	end)
	PlotService.onOwnerAdded(function(owner)
		if owner.player then
			show(owner)
			owner.player.CharacterAdded:Connect(function()
				task.wait(0.5)
				show(owner)
			end)
		end
	end)
	StateService.addProvider(function(player, state)
		local owner = PlotService.getOwner(player)
		if owner then
			state.titles = Titles.earned(TitleService.stats(owner))
			state.title = owner.profile.title
		end
	end)
end

return TitleService
