--!strict
-- Vânzările pe Robux (Config/Monetization, GDD §13).
-- Permisele: la intrare și la cumpărarea din joc se verifică proprietatea; efectele permanente (piedestale,
-- beci, straturi) se aplică o singură dată pe profil, iar cele de sesiune (2× lei, Papucul de Aur, VIP) se pun
-- ca multiplicator sau atribut pe jucător. Produsele: ProcessReceipt e idempotent (chitanțele procesate stau
-- în profil, salvat imediat), deci o plată nu se dă niciodată de două ori.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Monetization)
local Monetization = require(Shared.Domain.Monetization)
local Economy = require(Shared.Domain.Economy)
local PlotService = require(script.Parent.PlotService)
local DataService = require(script.Parent.DataService)
local StateService = require(script.Parent.StateService)
local EconomyService = require(script.Parent.EconomyService)
local CreatureService = require(script.Parent.CreatureService)
local GardenService = require(script.Parent.GardenService)
local WeatherService = require(script.Parent.WeatherService)
local Messenger = require(script.Parent.Messenger)

type Owner = PlotService.Owner

local MonetizationService = {}

local purchaseCallbacks: { (Player, string, number) -> () } = {}

-- Apelat după fiecare cumpărare acordată (măsurători): (jucător, cheie, Robux)
function MonetizationService.onPurchase(callback: (Player, string, number) -> ())
	table.insert(purchaseCallbacks, callback)
end

local function fire(player: Player, key: string, robux: number)
	for _, callback in purchaseCallbacks do
		task.spawn(callback, player, key, robux)
	end
end

local function owns(player: Player, passId: number): boolean
	local ok, result =
		pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
	return ok and result == true
end

-- Efectele unui permis deținut (permanente o dată, de sesiune de fiecare dată)
function MonetizationService.grantPass(player: Player, key: string)
	local owner = PlotService.getOwner(player)
	if not owner then
		return
	end
	if Monetization.applyPass(owner.profile, key) then
		CreatureService.render(owner)
		GardenService.refreshBeds(owner)
	end
	if key == "doublelei" then
		EconomyService.setBoost(player, Config.doubleLeiMultiplier)
	elseif key == "goldslipper" then
		player:SetAttribute("GoldenSlipper", true)
	elseif key == "vip" then
		player:SetAttribute("VIP", true)
		owner.plot.geometry.sign.Text = "★ " .. owner.name .. " ★"
	end
	StateService.markDirty(player)
end

local function checkPasses(owner: Owner)
	local player = owner.player
	if not player then
		return
	end
	for _, pass in Config.passes do
		if owns(player, pass.id) then
			MonetizationService.grantPass(player, pass.key)
		end
	end
end

-- Acordă un produs proprietarului unei ogrăzi (jucător sau bot de test); false dacă produsul nu există
function MonetizationService.grantProduct(owner: Owner, key: string): boolean
	local product = Config.productByKey[key]
	if not product then
		return false
	end
	local player = owner.player
	if product.kind == "lei" then
		local multiplier = if player then EconomyService.multiplier(player) else 1
		local income = Economy.totalIncome(owner.profile.pedestals, multiplier)
		local amount = Monetization.leiPack(key, income)
		EconomyService.addLei(owner, amount)
		Messenger.notify(player, "notify.LeiPack", { Economy.formatShort(amount) })
	elseif product.kind == "fertilizer" then
		GardenService.fertilize(owner)
		Messenger.notify(player, "notify.Fertilized")
	elseif product.kind == "weather" and product.weather then
		WeatherService.trigger(product.weather, true)
		Messenger.announce(
			"announce.WeatherGift",
			{ owner.name, Messenger.key("weather." .. product.weather) }
		)
	end
	return true
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local product = Config.productById[receipt.ProductId]
	if not player or not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local owner = PlotService.getOwner(player)
	if not owner then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if Monetization.wasProcessed(owner.profile, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if not MonetizationService.grantProduct(owner, product.key) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Monetization.recordReceipt(owner.profile, purchaseId)
	DataService.save(player)
	fire(player, product.key, receipt.CurrencySpent or 0)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MonetizationService.processReceipt = processReceipt

function MonetizationService.start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = Config.passById[passId]
		if purchased and pass then
			MonetizationService.grantPass(player, pass.key)
			Messenger.notify(player, "notify.PassBought", { Messenger.key("pass." .. pass.key) })
			fire(player, pass.key, 0)
		end
	end)
	PlotService.onOwnerAdded(function(owner)
		task.spawn(checkPasses, owner)
	end)
	StateService.addProvider(function(player, state)
		local owner = PlotService.getOwner(player)
		state.passes = if owner then owner.profile.passes else {}
	end)
end

return MonetizationService
