--!strict
-- Îngrijirea creaturilor: hrana (peștele întâi, apoi brânza cumpărată), mângâierea cu pauză, eticheta fericirii.

local ServerScriptService = game:GetService("ServerScriptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Inventory = require(Shared.Domain.Inventory)
local Care = require(Shared.Domain.Care)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local CreatureService = services.CreatureService
	local CareService = services.CareService

	describe("Îngrijirea creaturilor", function()
		it(
			"hrana: peștele întâi, apoi brânza cumpărată; mângâierea o dată la 30 s; modelul arată fericirea",
			function()
				local actor = Actors.createBot("Ingrijitor", PlotService.plots[6].geometry.spawnCFrame)
				local owner = PlotService.assignBot(PlotService.plots[6], actor)
				local record = Inventory.newRecord(owner.profile, actor.id, "Mamaligator", "Normal", nil)
				local key = select(2, Inventory.place(owner.profile, record)) :: string
				CreatureService.render(owner)
				owner.profile.fish = { crapRacheta = 1 }
				owner.profile.lei = 100
				expect(CareService.feed(owner, record.uid)).toBe("peste")
				expect(owner.profile.fish.crapRacheta).toBe(0)
				expect(record.happiness).toBe(Care.START + Care.FOOD.peste)
				expect(CareService.feed(owner, record.uid)).toBe("branza")
				expect(owner.profile.lei).toBe(100 - CareService.CHEESE_PRICE)
				expect(CareService.pet(owner, record.uid)).toBe(true)
				expect(CareService.pet(owner, record.uid)).toBe(false)
				local model = CreatureService.modelAt(owner, key) :: Model
				expect(model:GetAttribute("Happiness")).toBe(math.floor(record.happiness :: number))
				Actors.removeBot(actor)
			end
		)
	end)
end
