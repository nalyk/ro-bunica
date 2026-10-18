--!strict
-- Garderoba Bunicii (Config/Outfits): cumperi o ținută pe lei și o îmbraci; piesele se sudează pe Bunica din
-- ograda ta (vizual). La plecare, Bunica rămâne în hainele ei obișnuite.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Outfits = require(Shared.Config.Outfits)
local Subscription = require(Shared.Domain.Subscription)
local RateLimiter = require(Shared.Domain.RateLimiter)
local PlotService = require(script.Parent.PlotService)
local BunicaService = require(script.Parent.BunicaService)
local EconomyService = require(script.Parent.EconomyService)
local StateService = require(script.Parent.StateService)
local Messenger = require(script.Parent.Messenger)
local Analytics = require(script.Parent.Parent.Analytics)

type Owner = PlotService.Owner

local OutfitService = {}

local limiter = RateLimiter.new(6, 2)

local function clear(plotIndex: number)
	local rig = BunicaService.rigFor(plotIndex)
	local old = rig and rig:FindFirstChild("Tinuta")
	if old then
		old:Destroy()
	end
end

local function subscribed(owner: Owner): boolean
	return owner.player ~= nil and owner.player:GetAttribute("Subscriber") == true
end

-- Îmbracă Bunica ogrăzii cu ținuta proprietarului (sau nimic)
function OutfitService.apply(owner: Owner)
	clear(owner.plot.index)
	local outfit = owner.profile.outfit and Outfits.byId[owner.profile.outfit]
	-- ținuta abonaților rămâne în profil, dar nu se poartă cât abonamentul e oprit
	if outfit and outfit.subscriber and not subscribed(owner) then
		outfit = nil
	end
	local rig, head = BunicaService.rigFor(owner.plot.index)
	if not outfit or not rig or not head then
		return
	end
	local root = rig.PrimaryPart or head
	local folder = Instance.new("Model")
	folder.Name = "Tinuta"
	for _, piece in outfit.pieces do
		local anchor = if piece.attach == "head" then head else root
		local part = Instance.new("Part")
		part.Name = piece.name
		part.Shape = if piece.shape == "Ball"
			then Enum.PartType.Ball
			elseif piece.shape == "Cylinder" then Enum.PartType.Cylinder
			else Enum.PartType.Block
		part.Size = piece.size
		part.Color = piece.color
		part.Material = piece.material or Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.Anchored = false
		part.CFrame = anchor.CFrame * piece.offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = anchor
		weld.Part1 = part
		weld.Parent = part
		part.Parent = folder
	end
	folder.Parent = rig
end

function OutfitService.buy(owner: Owner, id: string): boolean
	local outfit = Outfits.byId[id]
	if not outfit or owner.profile.outfits[id] or not Subscription.canBuy(outfit) then
		return false
	end
	if owner.profile.lei < outfit.price then
		Messenger.notify(owner.player, "notify.NotEnoughLei")
		return false
	end
	EconomyService.addLei(owner, -outfit.price)
	owner.profile.outfits[id] = true
	Analytics.sink(owner.player, owner.profile, outfit.price, "Outfit", id)
	StateService.markDirty(owner.player)
	return true
end

function OutfitService.wear(owner: Owner, id: string?): boolean
	local outfit = if id then Outfits.byId[id] else nil
	if
		id ~= nil
		and not (
			outfit and Subscription.canWear(outfit, owner.profile.outfits[id] == true, subscribed(owner))
		)
	then
		return false
	end
	owner.profile.outfit = id
	OutfitService.apply(owner)
	StateService.markDirty(owner.player)
	return true
end

function OutfitService.start()
	Net.get("BuyOutfit").OnServerEvent:Connect(function(player, id)
		local owner = PlotService.getOwner(player)
		if owner and typeof(id) == "string" and limiter:allow(player.UserId, os.clock()) then
			OutfitService.buy(owner, id)
		end
	end)
	Net.get("WearOutfit").OnServerEvent:Connect(function(player, id)
		local owner = PlotService.getOwner(player)
		if owner and (id == nil or typeof(id) == "string") and limiter:allow(player.UserId, os.clock()) then
			OutfitService.wear(owner, id)
		end
	end)
	PlotService.onOwnerAdded(function(owner)
		OutfitService.apply(owner)
	end)
	PlotService.onOwnerRemoving(function(owner)
		clear(owner.plot.index)
	end)
	StateService.addProvider(function(player, state)
		local owner = PlotService.getOwner(player)
		if owner then
			state.outfits = owner.profile.outfits
			state.outfit = owner.profile.outfit
		end
	end)
end

return OutfitService
