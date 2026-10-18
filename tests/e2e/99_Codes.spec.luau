--!strict
-- Codurile tantii de la magazin și alarma în lanț (câinii vecinilor latră la hoțul care cară).

local ServerScriptService = game:GetService("ServerScriptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Inventory = require(Shared.Domain.Inventory)
local World = require(Shared.Config.World)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local CodeService = services.CodeService
	local CreatureService = services.CreatureService
	local RaidService = services.RaidService
	local DayNightService = services.DayNightService
	local BunicaService = services.BunicaService

	describe("Codurile și alarma în lanț", function()
		it("codul BUNICA dă 1000 de lei o singură dată; unul inventat e refuzat", function()
			local actor = Actors.createBot("Coduri", PlotService.plots[6].geometry.spawnCFrame)
			local owner = PlotService.assignBot(PlotService.plots[6], actor)
			local before = owner.profile.lei
			expect((CodeService.redeem(owner, "bunica"))).toBe(true)
			expect(owner.profile.lei - before).toBe(1000)
			expect((CodeService.redeem(owner, "BUNICA"))).toBe(false)
			expect((CodeService.redeem(owner, "NUEXISTA"))).toBe(false)
			Actors.removeBot(actor)
		end)

		it("hoțul care cară trece pe lângă poarta unui vecin: câinii vecinului latră", function()
			DayNightService.forcePhase("Night")
			BunicaService.setEnabled(false)
			local victimBot = Actors.createBot("Pradat", PlotService.plots[2].geometry.spawnCFrame)
			local victim = PlotService.assignBot(PlotService.plots[2], victimBot)
			local record = Inventory.newRecord(victim.profile, victimBot.id, "CartofelAgent", "Normal", nil)
			local key = select(2, Inventory.place(victim.profile, record)) :: string
			CreatureService.render(victim)
			local thief = Actors.createBot("HotLant", PlotService.plots[3].geometry.spawnCFrame)
			PlotService.assignBot(PlotService.plots[3], thief)
			local character = Actors.characterOf(thief) :: Model
			character:PivotTo(CreatureService.modelAt(victim, key):GetPivot() * CFrame.new(0, 0, -4))
			RaidService.tryStart(thief, victim, key)
			expect(RaidService.isCarrying(thief)).toBe(true)
			-- trece pe lângă poarta ogrăzii 1
			local neighbour = PlotService.plots[1]
			local gate = (neighbour.geometry.cframe * CFrame.new(0, 3, -World.plotSize.Z / 2 - 6)).Position
			character:PivotTo(CFrame.new(gate))
			expect(Spec.waitFor(function()
				local untilTime = neighbour.geometry.model:GetAttribute("BarkUntil")
				return typeof(untilTime) == "number" and untilTime > workspace:GetServerTimeNow()
			end, 3)).toBe(true)
			RaidService.drop(thief)
			Actors.removeBot(thief)
			Actors.removeBot(victimBot)
			BunicaService.setEnabled(true)
			DayNightService.forcePhase(nil)
		end)
	end)
end
