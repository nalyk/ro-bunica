--!strict
-- Politicile Roblox pe jucător (RegionPolicyService): unde schimbul de lucruri plătite nu e permis, nici
-- schimburile, nici bazarul nu merg, în niciun sens.

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
	local TradeService = services.TradeService
	local RegionPolicyService = services.RegionPolicyService
	local bazaar = VillageLayout.build().sites.bazar.Position
	local RESTRICTED = { randomRestricted = true, tradingAllowed = false }

	local function bot(name: string, index: number): (any, any)
		local actor = Actors.createBot(name, PlotService.plots[index].geometry.spawnCFrame)
		local owner = PlotService.assignBot(PlotService.plots[index], actor);
		(Actors.characterOf(actor) :: Model):PivotTo(CFrame.new(bazaar + Vector3.new(index, 3, 0)))
		return actor, owner
	end

	describe("Politicile Roblox", function()
		it("fără schimb permis: nu ceri, nu ești cerut, nu vinzi și nu cumperi la bazar", function()
			local botA, a = bot("Restrictionat", 6)
			local botB, b = bot("Liber", 7)
			RegionPolicyService.set(a.userId, RESTRICTED)
			expect(TradeService.request(a, b)).toBe(false)
			expect(TradeService.request(b, a)).toBe(false)
			expect(TradeService.isTrading(a) or TradeService.isTrading(b)).toBe(false)

			local mine = Inventory.newRecord(a.profile, botA.id, "Mamaligator", "Normal", nil)
			table.insert(a.profile.cellar, mine)
			local id, reason = MarketService.list(a, mine.uid, Economy.sellPrice(mine))
			expect(id == nil).toBe(true)
			expect(reason).toBe("Policy")

			local theirs = Inventory.newRecord(b.profile, botB.id, "CeapaTurbo", "Normal", nil)
			table.insert(b.profile.cellar, theirs)
			local listing = MarketService.list(b, theirs.uid, Economy.sellPrice(theirs)) :: string
			expect(listing ~= nil).toBe(true)
			a.profile.lei = 1000000
			local ok, why = MarketService.buy(a, listing)
			expect(ok).toBe(false)
			expect(why).toBe("Policy")
			expect(Inventory.findCellar(a.profile, theirs.uid) == nil).toBe(true)

			-- cu politica ridicată totul merge din nou
			RegionPolicyService.set(a.userId, nil)
			expect((MarketService.buy(a, listing))).toBe(true)
			Actors.removeBot(botA)
			Actors.removeBot(botB)
		end)

		it(
			"prețuri regionale diferite (Managed Pricing): fără schimb; la bazar leii nu urcă spre regiunea scumpă",
			function()
				local botA, cheap = bot("Ieftin", 6)
				local botB, full = bot("Scump", 7)
				RegionPolicyService.set(
					cheap.userId,
					{ randomRestricted = false, tradingAllowed = true, priceLevel = 300 }
				)
				RegionPolicyService.set(
					full.userId,
					{ randomRestricted = false, tradingAllowed = true, priceLevel = 1000 }
				)
				expect(TradeService.request(cheap, full)).toBe(false)
				expect(TradeService.request(full, cheap)).toBe(false)

				-- cel din regiunea ieftină nu cumpără de la cel din regiunea scumpă (leii ar urca)
				local fromFull = Inventory.newRecord(full.profile, botB.id, "CeapaTurbo", "Normal", nil)
				table.insert(full.profile.cellar, fromFull)
				local listing = MarketService.list(full, fromFull.uid, Economy.sellPrice(fromFull)) :: string
				cheap.profile.lei = 1000000
				local ok, why = MarketService.buy(cheap, listing)
				expect(ok).toBe(false)
				expect(why).toBe("PriceLevel")

				-- invers merge: leii coboară spre regiunea ieftină
				local fromCheap = Inventory.newRecord(cheap.profile, botA.id, "Mamaligator", "Normal", nil)
				table.insert(cheap.profile.cellar, fromCheap)
				local other = MarketService.list(cheap, fromCheap.uid, Economy.sellPrice(fromCheap)) :: string
				full.profile.lei = 1000000
				expect((MarketService.buy(full, other))).toBe(true)

				-- niveluri apropiate: schimbul e permis
				RegionPolicyService.set(
					cheap.userId,
					{ randomRestricted = false, tradingAllowed = true, priceLevel = 990 }
				)
				expect(TradeService.request(cheap, full)).toBe(true)
				TradeService.cancel(cheap)
				RegionPolicyService.set(cheap.userId, nil)
				RegionPolicyService.set(full.userId, nil)
				Actors.removeBot(botA)
				Actors.removeBot(botB)
			end
		)
	end)
end
