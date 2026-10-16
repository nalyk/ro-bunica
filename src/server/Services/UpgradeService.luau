--!strict
-- Îmbunătățirile ogrăzii, cumpărate cu lei. Serverul verifică prețul și nivelul (Domain/Upgrades), salvează
-- în profil și aplică efectul pe loc: piedestalele și straturile deblocate apar imediat în ogradă.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local RateLimiter = require(Shared.Domain.RateLimiter)
local Upgrades = require(Shared.Domain.Upgrades)
local Economy = require(Shared.Domain.Economy)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)
local EconomyService = require(script.Parent.EconomyService)
local CreatureService = require(script.Parent.CreatureService)
local GardenService = require(script.Parent.GardenService)
local Messenger = require(script.Parent.Messenger)
local ArtLibrary = require(Shared.Visual.ArtLibrary)
local World = require(Shared.Config.World)

local CollectionService = game:GetService("CollectionService")

type Owner = PlotService.Owner

local UpgradeService = {}

local limiter = RateLimiter.new(6, 3)
local purchaseCallbacks: { (Owner, string, number) -> () } = {}

-- Apelat după fiecare cumpărare reușită (măsurători, insigne)
function UpgradeService.onPurchased(callback: (Owner, string, number) -> ())
	table.insert(purchaseCallbacks, callback)
end

UpgradeService.DOG_TAG = "Grivei"

-- Grivei stă lângă prispă, cu fața spre drum, din clipa în care e cumpărat (model din art/, doar vizual)
local function renderDog(owner: Owner)
	local container = owner.plot.geometry.model
	local existing = container:FindFirstChild("Grivei")
	if Upgrades.level(owner.profile, "dog") <= 0 then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end
	local model = ArtLibrary.get("char.Grivei")
	if not model then
		return
	end
	model.Name = "Grivei"
	-- în fața prispei, la stânga Bunicii, cu fața spre drum (Bunica stă la Z/2 − 17)
	local at = owner.plot.geometry.cframe * CFrame.new(-7, 0, World.plotSize.Z / 2 - 23)
	model:PivotTo(at)
	local box, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(at.X - box.X, at.Y - (box.Y - size.Y / 2), at.Z - box.Z))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
		end
	end
	model:SetAttribute("Barking", false)
	CollectionService:AddTag(model, UpgradeService.DOG_TAG)
	model.Parent = container
end

UpgradeService.renderDog = renderDog

-- Cumpără pentru un proprietar (folosit de remote și de teste). Întoarce rezultatul din Domain/Upgrades.
function UpgradeService.buy(owner: Owner, id: string): Upgrades.BuyResult
	local result: Upgrades.BuyResult, cost = Upgrades.buy(owner.profile, id)
	if result ~= "ok" then
		return result
	end
	EconomyService.addLei(owner, 0) -- clasamentul și starea, după scăderea prețului
	if id == "pedestal" or id == "cellar" then
		CreatureService.render(owner)
	elseif id == "bed" then
		GardenService.refreshBeds(owner)
	elseif id == "dog" then
		renderDog(owner)
	end
	StateService.markDirty(owner.player)
	for _, callback in purchaseCallbacks do
		task.spawn(callback, owner, id, cost :: number)
	end
	return "ok" :: Upgrades.BuyResult
end

local function onBuy(player: Player, id: unknown)
	if type(id) ~= "string" or not limiter:allow(player.UserId, os.clock()) then
		return
	end
	local owner = PlotService.getOwner(player)
	if not owner then
		return
	end
	local result = UpgradeService.buy(owner, id)
	if result == "ok" then
		Messenger.notify(player, "notify.UpgradeBought", { Messenger.key("upgrade." .. id) })
	elseif result == "lei" then
		local cost = Upgrades.nextCost(owner.profile, id) or 0
		Messenger.notify(player, "notify.NotEnoughLei", { Economy.formatShort(cost) })
	end
end

function UpgradeService.start()
	Net.get("BuyUpgrade").OnServerEvent:Connect(onBuy)
	PlotService.onOwnerAdded(renderDog)
	PlotService.onOwnerRemoving(function(owner)
		local dog = owner.plot.geometry.model:FindFirstChild("Grivei")
		if dog then
			dog:Destroy()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player.UserId)
	end)
end

return UpgradeService
