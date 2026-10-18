local EggDuel = require(Shared.Domain.EggDuel)
local Scatter = require(Shared.Domain.Scatter)

describe("EggDuel", function()
	it("întoarce mereu A sau B", function()
		local rng = Scatter.rng(1)
		for _ = 1, 50 do
			local winner = EggDuel.resolve("Alb", "Auriu", rng)
			expect(winner == "A" or winner == "B").toBe(true)
		end
	end)
	it("oul mai tare câștigă mai des, dar nu mereu (contează și norocul)", function()
		local rng = Scatter.rng(7)
		local wins = 0
		for _ = 1, 2000 do
			if EggDuel.resolve("Auriu", "Alb", rng) == "A" then
				wins += 1
			end
		end
		expect(wins > 1300).toBe(true)
		expect(wins < 2000).toBe(true)
	end)
	it("ouăle egale au șanse egale", function()
		local rng = Scatter.rng(3)
		local wins = 0
		for _ = 1, 2000 do
			if EggDuel.resolve("Rosu", "Rosu", rng) == "A" then
				wins += 1
			end
		end
		expect(wins > 880 and wins < 1120).toBe(true)
	end)
	it("fiecare ou are o tărie; cel mai slab e oul alb", function()
		expect(EggDuel.strength("Alb") < EggDuel.strength("Rosu")).toBe(true)
		expect(EggDuel.strength("Incondeiat") < EggDuel.strength("Auriu")).toBe(true)
		expect(EggDuel.weakest({ Auriu = 1, Rosu = 2 })).toBe("Rosu")
		expect(EggDuel.weakest({})).toBeNil()
	end)
end)
