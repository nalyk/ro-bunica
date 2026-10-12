local Growth = require(Shared.Domain.Growth)
local RandomUtil = require(Shared.Domain.Random)

describe("Growth", function()
	it("o plantă nouă pornește de la zero", function()
		local plant = Growth.newPlant("CartofelAgent", RandomUtil.seeded(1))
		expect(plant.grown).toBe(0)
		expect(Growth.isReady(plant)).toBe(false)
	end)

	it("sămânța necunoscută aruncă eroare", function()
		expect(function()
			Growth.newPlant("Nimic", RandomUtil.seeded(1))
		end).toThrow("Sămânță necunoscută")
	end)

	it("crește până la gata și nu depășește", function()
		local plant = { seedId = "CartofelAgent", size = "Normal", grown = 0 }
		expect(Growth.advance(plant, 10, 1)).toBe(false)
		expect(Growth.progress(plant)).toBeCloseTo(0.5)
		expect(Growth.advance(plant, 100, 1)).toBe(true)
		expect(plant.grown).toBe(20)
	end)

	it("viteza (ploaia) accelerează creșterea", function()
		local plant = { seedId = "CartofelAgent", size = "Normal", grown = 0 }
		Growth.advance(plant, 10, 1.5)
		expect(plant.grown).toBe(15)
		expect(Growth.secondsLeft(plant, 1)).toBe(5)
	end)

	it("mărimile urmează ponderile", function()
		local rng = RandomUtil.seeded(42)
		local counts = {}
		for _ = 1, 10000 do
			local size = Growth.rollSize(rng)
			counts[size] = (counts[size] or 0) + 1
		end
		expect(counts.Normal).toBeGreaterThan(5500)
		expect(counts.Normal).toBeLessThan(6500)
		expect(counts.Huge).toBeGreaterThan(100)
		expect(counts.Huge).toBeLessThan(320)
	end)
end)
