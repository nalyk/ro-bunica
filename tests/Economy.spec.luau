local Economy = require(Shared.Domain.Economy)

describe("Economy", function()
	it("venitul de bază fără multiplicatori", function()
		expect(Economy.incomePerSecond({ id = "CartofelAgent", size = "Normal" })).toBe(1)
	end)

	it("mutația și mărimea se înmulțesc", function()
		-- Pepene Boxer 60 × Big 1.5 × Golden 10
		expect(Economy.incomePerSecond({ id = "PepeneBoxer", size = "Big", mutation = "Golden" })).toBe(900)
	end)

	it("creatură necunoscută valorează 0", function()
		expect(Economy.incomePerSecond({ id = "Nimic", size = "Normal" })).toBe(0)
	end)

	it("prețul de vânzare", function()
		expect(Economy.sellPrice({ id = "CovrigSkater", size = "Normal" })).toBe(150)
	end)

	it("bonusul de prieteni e plafonat", function()
		expect(Economy.friendMultiplier(0)).toBe(1)
		expect(Economy.friendMultiplier(2)).toBeCloseTo(1.2)
		expect(Economy.friendMultiplier(20)).toBeCloseTo(1.5)
	end)

	it("venitul total", function()
		local displayed = {
			["1"] = { id = "CartofelAgent", size = "Normal" },
			["2"] = { id = "ArdeiasIute", size = "Normal" },
		}
		expect(Economy.totalIncome(displayed, 2)).toBe(8)
	end)

	it("venitul offline e plafonat la 8 ore și 10%", function()
		expect(Economy.offlineEarnings(100, 3600)).toBe(36000)
		expect(Economy.offlineEarnings(100, 100 * 3600)).toBe(288000)
		expect(Economy.offlineEarnings(100, -5)).toBe(0)
	end)

	it("formatarea scurtă", function()
		expect(Economy.formatShort(950)).toBe("950")
		expect(Economy.formatShort(1200)).toBe("1.2K")
		expect(Economy.formatShort(1000)).toBe("1K")
		expect(Economy.formatShort(3456789)).toBe("3.4M")
		expect(Economy.formatShort(250000000)).toBe("250M")
		expect(Economy.formatShort(0.5)).toBe("0.5")
		expect(Economy.formatShort(7.25)).toBe("7.2")
		expect(Economy.formatShort(3.04)).toBe("3")
		expect(Economy.formatShort(12.9)).toBe("12")
	end)
end)
