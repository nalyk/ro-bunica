local Upgrades = require(Shared.Domain.Upgrades)
local DataTemplate = require(Shared.Config.DataTemplate)
local Economy = require(Shared.Config.Economy)

describe("Upgrades", function()
	it("primul piedestal costă prețul de bază, apoi prețul crește", function()
		local profile = DataTemplate.new()
		expect(Upgrades.nextCost(profile, "pedestal")).toBe(150)
		profile.lei = 1000
		local result, cost = Upgrades.buy(profile, "pedestal")
		expect(result).toBe("ok")
		expect(cost).toBe(150)
		expect(profile.lei).toBe(850)
		expect(profile.pedestalCount).toBe(Economy.startingPedestals + 1)
		expect(Upgrades.nextCost(profile, "pedestal")).toBe(320) -- 150 × 2,1 = 315 → 320
	end)

	it("fără lei destui nu cumpără și nu schimbă nimic", function()
		local profile = DataTemplate.new()
		profile.lei = 10
		local result, cost = Upgrades.buy(profile, "bed")
		expect(result).toBe("lei")
		expect(cost).toBe(200)
		expect(profile.lei).toBe(10)
		expect(profile.bedCount).toBe(Economy.startingBeds)
	end)

	it("straturile se opresc la maximul ogrăzii", function()
		local profile = DataTemplate.new()
		profile.lei = 10 ^ 9
		local bought = 0
		while Upgrades.buy(profile, "bed") == "ok" do
			bought += 1
		end
		expect(bought).toBe(Economy.maxBeds - Economy.startingBeds)
		expect(profile.bedCount).toBe(Economy.maxBeds)
		expect(Upgrades.nextCost(profile, "bed")).toBeNil()
	end)

	it("piedestalele date de un game pass scad câte mai rămân de cumpărat", function()
		local profile = DataTemplate.new()
		profile.pedestalCount = Economy.maxPedestals
		expect(Upgrades.nextCost(profile, "pedestal")).toBeNil()
	end)

	it("beciul crește cu 10 locuri, papucii se reîncarcă mai repede, Grivei încetinește", function()
		local profile = DataTemplate.new()
		profile.lei = 10 ^ 9
		local capacity = profile.cellarCapacity
		Upgrades.buy(profile, "cellar")
		expect(profile.cellarCapacity).toBe(capacity + 10)
		expect(Upgrades.regenSeconds(profile)).toBe(2.5)
		Upgrades.buy(profile, "regen")
		expect(math.abs(Upgrades.regenSeconds(profile) - 2.2) < 1e-9).toBe(true)
		expect(Upgrades.dogSlow(profile)).toBe(1)
		Upgrades.buy(profile, "dog")
		expect(Upgrades.dogSlow(profile)).toBe(0.85)
		expect(Upgrades.suspicionMultiplier(profile)).toBe(1)
		Upgrades.buy(profile, "sharp")
		expect(Upgrades.suspicionMultiplier(profile)).toBe(1.4)
	end)

	it("o îmbunătățire necunoscută e refuzată", function()
		local profile = DataTemplate.new()
		expect((Upgrades.buy(profile, "racheta"))).toBe("unknown")
	end)
end)
