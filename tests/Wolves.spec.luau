local Wolves = require(Shared.Domain.Wolves)

describe("Wolves", function()
	it("cu un jucător vin 3 lupi, cu mai mulți vin 6", function()
		expect(Wolves.count(0)).toBe(3)
		expect(Wolves.count(1)).toBe(3)
		expect(Wolves.count(2)).toBe(6)
		expect(Wolves.count(8)).toBe(6)
	end)
	it("un lup e gonit din 2 lovituri", function()
		expect(Wolves.HITS_TO_SCARE).toBe(2)
	end)
	it("oile fug dacă ajung 3 lupi în țarc", function()
		expect(Wolves.failed(2)).toBe(false)
		expect(Wolves.failed(3)).toBe(true)
	end)
	it(
		"răsplata se împarte după lovituri; fiecare participant primește cel puțin o parte mică",
		function()
			local shares = Wolves.split({ a = 6, b = 2, c = 0 }, 300)
			expect(shares.a > shares.b).toBe(true)
			expect(shares.c > 0).toBe(true)
			local total = 0
			for _, v in shares do
				total += v
			end
			expect(total <= 300).toBe(true)
			expect(total >= 297).toBe(true)
		end
	)
end)
