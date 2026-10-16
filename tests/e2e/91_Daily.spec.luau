--!strict
-- Recompensa zilnică pe serverul real: o dată pe zi, seria urcă în zile la rând.

local ServerScriptService = game:GetService("ServerScriptService")

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local DailyService = services.DailyService

	describe("Darul Bunicii", function()
		it("o dată pe zi, iar a doua zi seria urcă", function()
			local plot = PlotService.plots[5]
			local bot = Actors.createBot("Nepot", plot.geometry.spawnCFrame)
			local owner = PlotService.assignBot(plot, bot)
			owner.profile.lei = 0
			local day = 20000 * 86400
			local first = DailyService.claim(owner, day)
			expect(first and first.day).toBe(1)
			expect(owner.profile.lei).toBe(100)
			expect(DailyService.claim(owner, day + 3600) == nil).toBe(true)
			local second = DailyService.claim(owner, day + 86400)
			expect(second and second.day).toBe(2)
			expect(owner.profile.lei).toBe(300)
			Actors.removeBot(bot)
		end)
	end)
end
