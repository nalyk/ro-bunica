--!strict
-- Clasamentele săptămânale (LeaderboardService, OrderedDataStore): punctele adunate pe server se scriu,
-- se adună peste ce era și topul le întoarce ordonate. Testul scrie într-o săptămână separată („TEST…”),
-- nu în clasamentul real.

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local LeaderboardService = services.LeaderboardService

	describe("Clasamentele săptămânale", function()
		it("adună, scrie, ordonează", function()
			local week = "TEST" .. tostring(os.time())
			LeaderboardService.add(1, "papuc", 2)
			LeaderboardService.add(156, "papuc", 5)
			LeaderboardService.add(1, "papuc", 1)
			LeaderboardService.add(-5, "papuc", 9) -- boții nu intră
			LeaderboardService.add(1, "furt", 9) -- statistică necunoscută
			LeaderboardService.flush(week)
			LeaderboardService.add(1, "papuc", 4)
			LeaderboardService.flush(week)
			local top = LeaderboardService.top("papuc", week)
			expect(#top).toBe(2)
			expect(top[1][2]).toBe(7)
			expect(top[2][2]).toBe(5)
		end)
	end)
end
