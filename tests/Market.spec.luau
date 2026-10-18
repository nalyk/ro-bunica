local Market = require(Shared.Domain.Market)
local Economy = require(Shared.Domain.Economy)

local function profile(lei: number, cellar: { any })
	return { lei = lei, cellar = cellar, cellarCapacity = 10, pedestals = {} }
end

local function creature(uid: string, soul: boolean?)
	return { uid = uid, id = "Mamaligator", size = "Normal", soul = soul }
end

describe("Market", function()
	it("pune la vânzare doar din beci, cu preț între 25% și 10× din valoarea de vânzare", function()
		local market = Market.new(8)
		local seller = profile(0, { creature("a") })
		local value = Economy.sellPrice(creature("a"))
		expect((Market.list(market, 1, seller, "a", math.floor(value * 0.2)))).toBe(nil)
		expect((Market.list(market, 1, seller, "a", value * 11))).toBe(nil)
		local id = Market.list(market, 1, seller, "a", value)
		expect(id ~= nil).toBe(true)
		-- creatura rămâne în beci, marcată (dacă serverul cade, nu se pierde nimic)
		expect(#seller.cellar).toBe(1)
		expect(seller.cellar[1].listed).toBe(id)
	end)
	it("sufletele nu se vând; cel mult 4 creaturi pe tarabă; o tarabă de jucător", function()
		local market = Market.new(8)
		local seller = profile(
			0,
			{ creature("s", true), creature("1"), creature("2"), creature("3"), creature("4"), creature("5") }
		)
		local value = Economy.sellPrice(creature("1"))
		local _, reason = Market.list(market, 1, seller, "s", value)
		expect(reason).toBe("Soul")
		for i = 1, 4 do
			expect(Market.list(market, 1, seller, tostring(i), value) ~= nil).toBe(true)
		end
		local _, full = Market.list(market, 1, seller, "5", value)
		expect(full).toBe("StallFull")
	end)
	it(
		"cumpărarea mută creatura și leii deodată; fără lei sau loc în beci, nimic nu se schimbă",
		function()
			local market = Market.new(8)
			local seller = profile(100, { creature("a") })
			local value = Economy.sellPrice(creature("a"))
			local id = Market.list(market, 1, seller, "a", value) :: string
			local poor = profile(value - 1, {})
			expect((Market.buy(market, seller, poor, 2, id))).toBe(false)
			expect(seller.lei).toBe(100)
			local buyer = profile(value + 50, {})
			expect((Market.buy(market, seller, buyer, 2, id))).toBe(true)
			expect(buyer.lei).toBe(50)
			expect(seller.lei).toBe(100 + value)
			expect(#buyer.cellar).toBe(1)
			expect(buyer.cellar[1].uid).toBe("a")
			expect(buyer.cellar[1].listed).toBeNil()
			expect(#seller.cellar).toBe(0)
			expect((Market.buy(market, seller, buyer, 2, id))).toBe(false) -- vândută deja
		end
	)
	it("nu-ți cumperi propria creatură", function()
		local market = Market.new(8)
		local seller = profile(1000000, { creature("a") })
		local id = Market.list(market, 1, seller, "a", Economy.sellPrice(creature("a"))) :: string
		local ok, reason = Market.buy(market, seller, seller, 1, id)
		expect(ok).toBe(false)
		expect(reason).toBe("Own")
	end)
	it("când vânzătorul pleacă, taraba se golește și creaturile se întorc în beciul lui", function()
		local market = Market.new(8)
		local seller = profile(0, { creature("a"), creature("b") })
		local value = Economy.sellPrice(creature("a"))
		local id = Market.list(market, 1, seller, "a", value) :: string
		Market.list(market, 1, seller, "b", value)
		Market.close(market, 1, seller)
		expect(#seller.cellar).toBe(2)
		expect(seller.cellar[1].listed).toBeNil()
		local buyer = profile(1000000, {})
		expect((Market.buy(market, seller, buyer, 2, id))).toBe(false)
	end)
	it("o creatură pusă la vânzare nu se poate pune de două ori", function()
		local market = Market.new(8)
		local seller = profile(0, { creature("a") })
		local value = Economy.sellPrice(creature("a"))
		Market.list(market, 1, seller, "a", value)
		local _, reason = Market.list(market, 1, seller, "a", value)
		expect(reason).toBe("Listed")
	end)
	it("tarabele sunt limitate (8, iar duminica 12)", function()
		local market = Market.new(2)
		local value = Economy.sellPrice(creature("x"))
		expect(Market.list(market, 1, profile(0, { creature("a") }), "a", value) ~= nil).toBe(true)
		expect(Market.list(market, 2, profile(0, { creature("b") }), "b", value) ~= nil).toBe(true)
		local _, reason = Market.list(market, 3, profile(0, { creature("c") }), "c", value)
		expect(reason).toBe("NoStall")
		expect(Market.stallsFor(true)).toBe(12)
		expect(Market.stallsFor(false)).toBe(8)
	end)
end)
