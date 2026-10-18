--!strict
-- Bazarul cu boți: vânzarea, cumpărarea atomică, plecarea vânzătorului.

local ServerScriptService = game:GetService("ServerScriptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Inventory = require(Shared.Domain.Inventory)
local Economy = require(Shared.Domain.Economy)
local VillageLayout = require(Shared.Domain.VillageLayout)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local MarketService = services.MarketService
	local bazaar = VillageLayout.build().sites.bazar.Position

	local function bot(name: string, index: number): (any, any)
		local actor = Actors.createBot(name, PlotService.plots[index].geometry.spawnCFrame)
		local owner = PlotService.assignBot(PlotService.plots[index], actor);
		(Actors.characterOf(actor) :: Model):PivotTo(CFrame.new(bazaar + Vector3.new(index, 3, 0)))
		return actor, owner
	end

	describe("Bazarul", function()
		it(
			"vânzătorul pune, cumpărătorul ia (lei și creatură deodată); plecarea vânzătorului golește taraba",
			function()
				local sellerBot, seller = bot("Vanzator", 6)
				local buyerBot, buyer = bot("Cumparator", 7)
				local a = Inventory.newRecord(seller.profile, sellerBot.id, "Mamaligator", "Normal", nil)
				local b = Inventory.newRecord(seller.profile, sellerBot.id, "CeapaTurbo", "Normal", nil)
				table.insert(seller.profile.cellar, a)
				table.insert(seller.profile.cellar, b)
				local price = Economy.sellPrice(a)
				local id = MarketService.list(seller, a.uid, price)
				expect(id ~= nil).toBe(true)
				local idB = MarketService.list(seller, b.uid, Economy.sellPrice(b)) :: string
				buyer.profile.lei = price + 10
				local sellerLei = seller.profile.lei
				expect((MarketService.buy(buyer, id :: string))).toBe(true)
				expect(buyer.profile.lei).toBe(10)
				expect(seller.profile.lei).toBe(sellerLei + price)
				expect(Inventory.findCellar(buyer.profile, a.uid) ~= nil).toBe(true)
				expect(Inventory.findCellar(seller.profile, a.uid) == nil).toBe(true)
				Actors.removeBot(sellerBot) -- vânzătorul pleacă
				task.wait(0.5)
				buyer.profile.lei = 1000000
				expect((MarketService.buy(buyer, idB))).toBe(false)
				expect(MarketService.market().listings[idB] == nil).toBe(true)
				Actors.removeBot(buyerBot)
			end
		)
	end)
end
