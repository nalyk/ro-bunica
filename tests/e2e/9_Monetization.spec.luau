--!strict
-- Vânzările pe Robux pe serverul real (fără plată adevărată): produsele se acordă proprietarului,
-- iar efectele permanente ale permiselor se aplică o singură dată.

local ServerScriptService = game:GetService("ServerScriptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Monetization = require(Shared.Domain.Monetization)
local Inventory = require(Shared.Domain.Inventory)
local Growth = require(Shared.Domain.Growth)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local MonetizationService = services.MonetizationService
	local WeatherService = services.WeatherService

	describe("Magazinul pe Robux", function()
		it("punga de lei, îngrășământul și permisul VIP", function()
			local plot = PlotService.plots[6]
			local bot = Actors.createBot("Cumparator", plot.geometry.spawnCFrame)
			local owner = PlotService.assignBot(plot, bot)
			owner.profile.lei = 0
			expect(MonetizationService.grantProduct(owner, "lei_s")).toBe(true)
			expect(owner.profile.lei).toBe(500)
			-- o plantă abia pusă crește instant cu îngrășământul
			owner.profile.beds["1"] = Growth.newPlant("CartofelAgent", function()
				return 0.5
			end)
			expect(Growth.isReady(owner.profile.beds["1"])).toBe(false)
			expect(MonetizationService.grantProduct(owner, "fertilizer")).toBe(true)
			expect(Growth.isReady(owner.profile.beds["1"]) or owner.profile.beds["1"] == nil).toBe(true)
			-- VIP: +4 piedestale, o singură dată
			local before = owner.profile.pedestalCount
			expect(Monetization.applyPass(owner.profile, "vip")).toBe(true)
			expect(Monetization.applyPass(owner.profile, "vip")).toBe(false)
			expect(owner.profile.pedestalCount).toBe(before + 4)
			expect(MonetizationService.grantProduct(owner, "nu-exista")).toBe(false)
			local _ = Inventory
			Actors.removeBot(bot)
		end)

		it("semințele proaspete și vremea pentru tot satul", function()
			local plot = PlotService.plots[6]
			local bot = Actors.createBot("Cumparator", plot.geometry.spawnCFrame)
			local owner = PlotService.assignBot(plot, bot)
			expect(MonetizationService.grantProduct(owner, "restock")).toBe(true)
			-- vremea cumpărată pornește chiar peste o vreme în curs
			expect(MonetizationService.grantProduct(owner, "weather_rainbow")).toBe(true)
			expect(WeatherService.current().id).toBe("Rainbow")
			expect(MonetizationService.grantProduct(owner, "weather_gold")).toBe(true)
			expect(WeatherService.current().id).toBe("GoldHarvest")
			Actors.removeBot(bot)
		end)
	end)
end
