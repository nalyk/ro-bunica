local SkyCycle = require(Shared.Domain.SkyCycle)

describe("SkyCycle", function()
	it("la ora unui cadru-cheie întoarce exact cadrul", function()
		local look = SkyCycle.at(14)
		expect(look.brightness).toBeCloseTo(2.7)
	end)
	it("între cadre interpolează (luminozitatea între valori)", function()
		local b = SkyCycle.at(15.7).brightness
		expect(b < 2.7 and b > 2.3).toBe(true)
	end)
	it("trece neted peste miezul nopții", function()
		local late = SkyCycle.at(23.9).brightness
		local early = SkyCycle.at(0.1).brightness
		expect(math.abs(late - early) < 0.05).toBe(true)
	end)
	it("ora din fază: ziua 7 → 18,8, noaptea continuă până la zori", function()
		expect(SkyCycle.hourFor("Day", 0)).toBeCloseTo(7)
		expect(SkyCycle.hourFor("Day", 1)).toBeCloseTo(18.8)
		expect(SkyCycle.hourFor("Night", 0)).toBeCloseTo(18.8)
		expect(SkyCycle.hourFor("Night", 1)).toBeCloseTo(6.5)
		expect(SkyCycle.at(SkyCycle.hourFor("Night", 0.85)).brightness < 1.5).toBe(true) -- tot noapte
	end)
	it("toate cadrele au aceleași câmpuri", function()
		local fields = {}
		for key in SkyCycle.KEYS[1].look do
			fields[key] = true
		end
		for _, entry in SkyCycle.KEYS do
			for key in fields do
				expect(entry.look[key] ~= nil).toBe(true)
			end
		end
	end)
end)
