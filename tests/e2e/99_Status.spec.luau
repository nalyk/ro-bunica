--!strict
-- Drumurile spre statut: titlurile se aleg doar după prag; ținuta cumpărată se vede pe Bunica ogrăzii.

local ServerScriptService = game:GetService("ServerScriptService")

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local Progress = (require :: any)(ServerScriptService.Server:WaitForChild("Progress"))
	local PlotService = services.PlotService
	local TitleService = services.TitleService
	local OutfitService = services.OutfitService
	local BunicaService = services.BunicaService

	describe("Titlurile și garderoba", function()
		it("titlul „Pescarul” vine după 20 de pești; până atunci nu se poate alege", function()
			local actor = Actors.createBot("Titlu", PlotService.plots[6].geometry.spawnCFrame)
			local owner = PlotService.assignBot(PlotService.plots[6], actor)
			expect(TitleService.set(owner, "pescar")).toBe(false)
			for _ = 1, 20 do
				Progress.emit(owner, "fish")
			end
			expect(TitleService.stats(owner).fish).toBe(20)
			expect(TitleService.set(owner, "pescar")).toBe(true)
			expect(owner.profile.title).toBe("pescar")
			Actors.removeBot(actor)
		end)

		it("ținuta cumpărată și îmbrăcată apare pe Bunica din ogradă; scoasă, dispare", function()
			local actor = Actors.createBot("Garderoba", PlotService.plots[7].geometry.spawnCFrame)
			local owner = PlotService.assignBot(PlotService.plots[7], actor)
			owner.profile.lei = 100000
			expect(OutfitService.wear(owner, "hram")).toBe(false) -- nu e a ta
			expect(OutfitService.buy(owner, "hram")).toBe(true)
			expect(OutfitService.wear(owner, "hram")).toBe(true)
			local rig = BunicaService.rigFor(owner.plot.index)
			local outfit = rig and rig:FindFirstChild("Tinuta")
			expect(outfit ~= nil and outfit:FindFirstChild("Vesta") ~= nil).toBe(true)
			expect(OutfitService.wear(owner, nil)).toBe(true)
			expect((rig :: Model):FindFirstChild("Tinuta") == nil).toBe(true)
			Actors.removeBot(actor)
		end)
	end)
end
