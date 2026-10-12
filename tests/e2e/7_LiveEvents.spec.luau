--!strict
-- „Bunica se supără”: vremea exclusivă, sămânța exclusivă și ploaia de papuci peste hoți.

local ServerScriptService = game:GetService("ServerScriptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Inventory = require(Shared.Domain.Inventory)
local LiveEventsConfig = require(Shared.Config.LiveEvents)
local GameState = require(Shared.GameState)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local CreatureService = services.CreatureService
	local RaidService = services.RaidService
	local ShopService = services.ShopService
	local LiveEventService = services.LiveEventService
	local DayNightService = services.DayNightService
	local BunicaService = services.BunicaService

	describe("Bunica se supără", function()
		it("pornește vremea exclusivă și pune în vânzare sămânța săptămânii", function()
			LiveEventService.forceStart("BunicaSeSupara", 30)
			expect(GameState.get("LiveEvent")).toBe("BunicaSeSupara")
			expect(Spec.waitFor(function()
				return GameState.get("Weather") == "BunicaAngry"
			end, 4)).toBe(true)
			local exclusive = ShopService.exclusive()
			expect(table.find(LiveEventsConfig.byId.BunicaSeSupara.exclusives, exclusive) ~= nil).toBe(true)
		end)

		it("papucii din cer îl lovesc pe hoțul care cară o creatură", function()
			DayNightService.forcePhase("Night")
			BunicaService.setEnabled(false)
			local plot = PlotService.plots[5]
			local ownerBot = Actors.createBot("GazdaSupărată", plot.geometry.spawnCFrame)
			local owner = PlotService.assignBot(plot, ownerBot)
			Inventory.place(
				owner.profile,
				Inventory.newRecord(owner.profile, ownerBot.id, "CartofelAgent", "Normal", nil)
			)
			CreatureService.render(owner)
			local thiefPlot = PlotService.plots[6]
			local thief = Actors.createBot("HotSubCer", thiefPlot.geometry.spawnCFrame)
			PlotService.assignBot(thiefPlot, thief)
			local key = next(owner.profile.pedestals) :: string
			local model = CreatureService.modelAt(owner, key) :: Model
			(Actors.characterOf(thief) :: Model):PivotTo(model:GetPivot() * CFrame.new(0, 0, -4))
			RaidService.tryStart(thief, owner, key)
			expect(RaidService.isCarrying(thief)).toBe(true)
			expect(Spec.waitFor(function()
				return not RaidService.isCarrying(thief)
			end, 20)).toBe(true)
			expect(owner.profile.pedestals[key] ~= nil).toBe(true)
			Actors.removeBot(thief)
			Actors.removeBot(ownerBot)
			DayNightService.forcePhase(nil)
		end)

		it("se încheie și scoate exclusivitatea din vânzare", function()
			LiveEventService.stop()
			expect(GameState.get("LiveEvent")).toBe("")
			expect(ShopService.exclusive()).toBe(nil)
		end)
	end)
end
