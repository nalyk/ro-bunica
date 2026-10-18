local Policy = require(Shared.Domain.Policy)
local Config = require(Shared.Config.Monetization)

describe("Policy", function()
	it("răspunsul PolicyService se citește direct", function()
		local policy =
			Policy.fromInfo(true, { ArePaidRandomItemsRestricted = true, IsPaidItemTradingAllowed = false })
		expect(policy.randomRestricted).toBe(true)
		expect(policy.tradingAllowed).toBe(false)
		local free =
			Policy.fromInfo(true, { ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = true })
		expect(free.randomRestricted).toBe(false)
		expect(free.tradingAllowed).toBe(true)
	end)
	it(
		"fără răspuns (eroare sau câmpuri lipsă) e restricționat: nu ghicim în favoarea vânzării",
		function()
			local failed = Policy.fromInfo(false, "HTTP 500")
			expect(failed.randomRestricted).toBe(true)
			expect(failed.tradingAllowed).toBe(false)
			local empty = Policy.fromInfo(true, {})
			expect(empty.randomRestricted).toBe(true)
			expect(empty.tradingAllowed).toBe(false)
		end
	)
	it("cine e restricționat nu vede ce duce la rezultate aleatorii plătite; restul rămân", function()
		local restricted = Policy.fromInfo(true, { ArePaidRandomItemsRestricted = true })
		expect(Policy.canBuy(Config.productByKey.lei_s, restricted)).toBe(false)
		expect(Policy.canBuy(Config.productByKey.restock, restricted)).toBe(false)
		expect(Policy.canBuy(Config.productByKey.weather_gold, restricted)).toBe(false)
		expect(Policy.canBuy(Config.passByKey.doublelei, restricted)).toBe(false)
		expect(Policy.canBuy(Config.productByKey.fertilizer, restricted)).toBe(true)
		expect(Policy.canBuy(Config.passByKey.vip, restricted)).toBe(true)
		local free = Policy.fromInfo(true, { ArePaidRandomItemsRestricted = false })
		expect(Policy.canBuy(Config.productByKey.lei_s, free)).toBe(true)
	end)
	it("boții și proprietarii fără jucător au voie la toate", function()
		expect(Policy.OPEN.randomRestricted).toBe(false)
		expect(Policy.OPEN.tradingAllowed).toBe(true)
		expect(Policy.OPEN.priceLevel).toBe(1000)
	end)

	local function at(level: number?, trading: boolean?): any
		return { randomRestricted = false, tradingAllowed = trading ~= false, priceLevel = level }
	end

	it(
		"schimburile (valoare în ambele sensuri): doar între niveluri de preț apropiate (Managed Pricing)",
		function()
			expect(Policy.canTrade(at(1000), at(1000))).toBe(true)
			expect(Policy.canTrade(at(410), at(410 + Policy.PRICE_TOLERANCE))).toBe(true)
			expect(Policy.canTrade(at(410), at(410 + Policy.PRICE_TOLERANCE + 1))).toBe(false)
			expect(Policy.canTrade(at(300), at(1000))).toBe(false)
			expect(Policy.canTrade(at(1000), at(300))).toBe(false)
		end
	)

	it(
		"bazarul (leii merg de la cumpărător la vânzător): cumpărătorul nu poate fi dintr-o regiune mai ieftină",
		function()
			expect(Policy.canGive(at(1000), at(300))).toBe(true)
			expect(Policy.canGive(at(300), at(1000))).toBe(false)
			expect(Policy.canGive(at(500), at(500 + Policy.PRICE_TOLERANCE))).toBe(true)
		end
	)

	it("nivel necunoscut sau schimb nepermis: nu", function()
		expect(Policy.canTrade(at(nil), at(1000))).toBe(false)
		expect(Policy.canGive(at(1000), at(nil))).toBe(false)
		expect(Policy.canTrade(at(1000, false), at(1000))).toBe(false)
		expect(Policy.canGive(at(1000), at(1000, false))).toBe(false)
	end)
end)
