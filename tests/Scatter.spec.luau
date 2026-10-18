local Scatter = require(Shared.Domain.Scatter)

local AREA = { min = Vector2.new(0, 0), max = Vector2.new(200, 120) }

describe("Scatter", function()
	it("respectă distanța minimă și rămâne în zonă", function()
		local points = Scatter.poisson(AREA, 10, function()
			return true
		end, Scatter.rng(5))
		expect(#points > 80).toBe(true)
		for i, p in points do
			expect(p.X >= 0 and p.X <= 200 and p.Y >= 0 and p.Y <= 120).toBe(true)
			for j = i + 1, #points do
				expect((points[j] - p).Magnitude >= 10 - 1e-6).toBe(true)
			end
		end
	end)
	it("masca exclude zonele interzise (drumuri, ogrăzi)", function()
		local function mask(p: Vector2): boolean
			return not (p.X > 80 and p.X < 120) -- un „drum” vertical
		end
		for _, p in Scatter.poisson(AREA, 8, mask, Scatter.rng(9)) do
			expect(mask(p)).toBe(true)
		end
	end)
	it("e determinist pe seed", function()
		local a = Scatter.poisson(AREA, 12, function()
			return true
		end, Scatter.rng(3))
		local b = Scatter.poisson(AREA, 12, function()
			return true
		end, Scatter.rng(3))
		expect(#a).toBe(#b)
		for i = 1, #a do
			expect(a[i] == b[i]).toBe(true)
		end
	end)
end)
