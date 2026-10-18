local Subscription = require(Shared.Domain.Subscription)
local Titles = require(Shared.Domain.Titles)
local Outfits = require(Shared.Config.Outfits)

describe("Subscription", function()
	it("ținuta abonaților: doar cât ține abonamentul, fără cumpărare pe lei", function()
		local outfit = Outfits.byId[Subscription.OUTFIT]
		expect(outfit ~= nil and outfit.subscriber == true).toBe(true)
		expect(Subscription.canWear(outfit, false, true)).toBe(true)
		expect(Subscription.canWear(outfit, true, false)).toBe(false)
		expect(Subscription.canBuy(outfit)).toBe(false)
	end)

	it("ținutele obișnuite: cumpărate pe lei, purtate oricând", function()
		local outfit = Outfits.byId.sarbatoare
		expect(Subscription.canWear(outfit, true, false)).toBe(true)
		expect(Subscription.canWear(outfit, false, true)).toBe(false)
		expect(Subscription.canBuy(outfit)).toBe(true)
	end)

	it("titlul „Prietenul Bunicii” e al abonaților", function()
		expect(Titles.canUse({ subscriber = 1 }, "prietenBunicii")).toBe(true)
		expect(Titles.canUse({ subscriber = 0 }, "prietenBunicii")).toBe(false)
	end)
end)
