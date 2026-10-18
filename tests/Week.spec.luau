local Week = require(Shared.Domain.Week)

describe("Week", function()
	it("săptămâna ISO: luni–duminică, cu anul săptămânii", function()
		expect(Week.key(1792576800)).toBe("2026W43") -- miercuri 21 oct. 2026
		expect(Week.key(1792368000)).toBe("2026W43") -- luni 19 oct. 2026, 00:00
		expect(Week.key(1792367999)).toBe("2026W42") -- duminică 18 oct. 2026, 23:59:59
		expect(Week.key(1798675200)).toBe("2026W53") -- joi 31 dec. 2026
		expect(Week.key(1798761600)).toBe("2026W53") -- vineri 1 ian. 2027 (aparține săptămânii 53 din 2026)
		expect(Week.key(1799020800)).toBe("2027W01") -- luni 4 ian. 2027
	end)

	it("secunde până la săptămâna următoare (luni 00:00 UTC)", function()
		expect(Week.secondsLeft(1792368000)).toBe(7 * 86400)
		expect(Week.secondsLeft(1792367999)).toBe(1)
	end)
end)
