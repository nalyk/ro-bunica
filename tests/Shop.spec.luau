local Shop = require(Shared.Domain.Shop)

describe("Shop", function()
	it("cu noroc maxim, toate semințele de vânzare intră în stoc", function()
		local stock = Shop.restock(function()
			return 0
		end)
		expect(stock.CartofelAgent).toBe(8)
		expect(stock.DovleacDJ).toBe(1)
		expect(stock.RetetaSecreta).toBeNil()
		expect(stock.Papucel).toBeNil() -- exclusivitate de eveniment
	end)

	it("comunele intră mereu, chiar fără noroc", function()
		local stock = Shop.restock(function()
			return 0.999
		end)
		expect(stock.CartofelAgent).toBe(8)
		expect(stock.GogoasaNinja).toBeNil()
	end)

	it("verifică stocul, prețul și leii", function()
		local stock = { CartofelAgent = 1 }
		local ok, price = Shop.checkPurchase(stock, "CartofelAgent", 100)
		expect(ok).toBe(true)
		expect(price).toBe(10)
		ok, price = Shop.checkPurchase(stock, "CartofelAgent", 5)
		expect(price).toBe("NotEnoughLei")
		ok, price = Shop.checkPurchase(stock, "ArdeiasIute", 1000)
		expect(price).toBe("OutOfStock")
		ok, price = Shop.checkPurchase(stock, "RetetaSecreta", 1e9)
		expect(price).toBe("NotForSale")
	end)

	it("reînnoirea e aliniată la ceas", function()
		expect(Shop.nextRestockAt(0)).toBe(300)
		expect(Shop.nextRestockAt(299)).toBe(300)
		expect(Shop.nextRestockAt(300)).toBe(600)
	end)
end)
