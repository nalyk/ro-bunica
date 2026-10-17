local Trade = require(Shared.Domain.Trade)

local function profiles()
	return {
		[1] = {
			lei = 1000,
			cellarCapacity = 3,
			cellar = {
				{ uid = "a1", id = "CartofelAgent", size = "Normal" },
				{ uid = "a2", id = "PepeneBoxer", size = "Normal", mutation = "Wet" },
				{ uid = "a3", id = "RetetaSecreta", size = "Normal" },
			},
		},
		[2] = {
			lei = 50,
			cellarCapacity = 30,
			cellar = { { uid = "b1", id = "Mamaligator", size = "Huge" } },
		},
	}
end

describe("Trade", function()
	it("oferta: doar din beci, fără Secrete, cu leii pe care îi ai", function()
		local p = profiles()
		expect((Trade.checkOffer(p[1], { "a1", "a2" }, 500))).toBe(true)
		expect(select(2, Trade.checkOffer(p[1], { "zz" }, 0))).toBe("NotInCellar")
		expect(select(2, Trade.checkOffer(p[1], { "a3" }, 0))).toBe("NotTradable")
		expect(select(2, Trade.checkOffer(p[1], { "a1", "a1" }, 0))).toBe("Duplicate")
		expect(select(2, Trade.checkOffer(p[2], {}, 51))).toBe("NotEnoughLei")
		expect(select(2, Trade.checkOffer(p[2], {}, 1.5))).toBe("NotEnoughLei")
	end)
	it("orice schimbare de ofertă anulează acceptările", function()
		local p = profiles()
		local s = Trade.new(1, 2)
		Trade.setOffer(s, 1, p[1], { "a1" }, 0)
		expect(Trade.accept(s, 1)).toBe(false)
		Trade.setOffer(s, 2, p[2], { "b1" }, 10)
		expect(s.accepted[1]).toBe(false)
		expect(Trade.accept(s, 1)).toBe(false)
		expect(Trade.accept(s, 2)).toBe(true)
	end)
	it("valoarea arată prețul de vânzare plus leii", function()
		local p = profiles()
		expect(Trade.value(p[2], { uids = { "b1" }, lei = 10 })).toBe(120 * 3 * 30 + 10)
	end)
	it("execută totul sau nimic, cu loc în beci", function()
		local p = profiles()
		local s = Trade.new(1, 2)
		Trade.setOffer(s, 1, p[1], { "a1" }, 100)
		Trade.setOffer(s, 2, p[2], { "b1" }, 0)
		expect((Trade.validate(s, p))).toBe(true)
		local received = Trade.execute(s, p)
		expect(received[1][1].uid).toBe("b1")
		expect(received[2][1].uid).toBe("a1")
		expect(p[1].lei).toBe(900)
		expect(p[2].lei).toBe(150)
		expect(#p[1].cellar).toBe(3)
		expect(#p[2].cellar).toBe(1)
	end)
	it("refuză când beciul n-are loc sau creatura a dispărut între timp", function()
		local p = profiles()
		local s = Trade.new(1, 2)
		Trade.setOffer(s, 2, p[2], { "b1" }, 0)
		expect(select(2, Trade.validate(s, p))).toBe("Full") -- 3 + 1 > 3
		local q = profiles()
		local t = Trade.new(1, 2)
		Trade.setOffer(t, 1, q[1], { "a1" }, 0)
		table.remove(q[1].cellar, 1) -- vândută după ofertă
		expect(select(2, Trade.validate(t, q))).toBe("NotInCellar")
	end)
end)
