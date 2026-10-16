local Monetization = require(Shared.Domain.Monetization)
local DataTemplate = require(Shared.Config.DataTemplate)
local Economy = require(Shared.Config.Economy)

describe("Monetization", function()
	it("pachetele de lei: minimul pentru începători, venitul pe timp pentru cei avansați", function()
		expect(Monetization.leiPack("lei_s", 0)).toBe(500)
		expect(Monetization.leiPack("lei_s", 100)).toBe(60000) -- 10 minute × 100 lei/s
		expect(Monetization.leiPack("lei_m", 1)).toBe(5000)
		expect(Monetization.leiPack("necunoscut", 100)).toBe(0)
	end)

	it("VIP dă 4 piedestale o singură dată, fără să treacă de maximul ogrăzii", function()
		local profile = DataTemplate.new()
		local before = profile.pedestalCount
		expect(Monetization.applyPass(profile, "vip")).toBe(true)
		expect(profile.pedestalCount).toBe(before + 4)
		expect(Monetization.applyPass(profile, "vip")).toBe(false)
		expect(profile.pedestalCount).toBe(before + 4)
		local full = DataTemplate.new()
		full.pedestalCount = Economy.maxPedestals - 1
		Monetization.applyPass(full, "vip")
		expect(full.pedestalCount).toBe(Economy.maxPedestals)
	end)

	it("Beci mare și Grădinar", function()
		local profile = DataTemplate.new()
		local cellar, beds = profile.cellarCapacity, profile.bedCount
		Monetization.applyPass(profile, "bigcellar")
		Monetization.applyPass(profile, "gardener")
		expect(profile.cellarCapacity).toBe(cellar + 50)
		expect(profile.bedCount).toBe(beds + 2)
	end)

	it("o plată procesată nu se mai dă a doua oară; lista are o limită", function()
		local profile = DataTemplate.new()
		expect(Monetization.wasProcessed(profile, "a")).toBe(false)
		Monetization.recordReceipt(profile, "a")
		expect(Monetization.wasProcessed(profile, "a")).toBe(true)
		for i = 1, 250 do
			Monetization.recordReceipt(profile, "p" .. i)
		end
		expect(#profile.receipts).toBe(200)
		expect(Monetization.wasProcessed(profile, "a")).toBe(false)
		expect(Monetization.wasProcessed(profile, "p250")).toBe(true)
	end)
end)
