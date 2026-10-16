local Daily = require(Shared.Domain.Daily)
local DataTemplate = require(Shared.Config.DataTemplate)

describe("Daily", function()
	it("prima zi dă ziua 1, a doua oară în aceeași zi nimic", function()
		local profile = DataTemplate.new()
		profile.lei = 0
		local claim = Daily.claim(profile, 100)
		expect(claim and claim.day).toBe(1)
		expect(profile.lei).toBe(100)
		expect(Daily.claim(profile, 100)).toBeNil()
	end)

	it("zilele la rând urcă seria, ziua 7 dă și o sămânță rară, apoi o ia de la capăt", function()
		local profile = DataTemplate.new()
		local last
		for day = 1, 7 do
			last = Daily.claim(profile, 200 + day)
		end
		expect(last and last.day).toBe(7)
		expect(last and last.seed).toBe(Daily.SEED_DAY7)
		expect(profile.seeds[Daily.SEED_DAY7]).toBe(1)
		local again = Daily.claim(profile, 208)
		expect(again and again.day).toBe(1)
	end)

	it("o zi sărită resetează seria", function()
		local profile = DataTemplate.new()
		Daily.claim(profile, 300)
		Daily.claim(profile, 301)
		local claim = Daily.claim(profile, 303)
		expect(claim and claim.day).toBe(1)
	end)

	it("ziua UTC din secunde", function()
		expect(Daily.dayOf(0)).toBe(0)
		expect(Daily.dayOf(86399)).toBe(0)
		expect(Daily.dayOf(86400)).toBe(1)
	end)
end)
