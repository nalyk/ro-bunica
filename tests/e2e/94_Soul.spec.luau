--!strict
-- Creaturile de suflet: nu se fură, iar inima se pune prin serviciu (cel mult 3).

local ServerScriptService = game:GetService("ServerScriptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Inventory = require(Shared.Domain.Inventory)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local CreatureService = services.CreatureService
	local RaidService = services.RaidService
	local DayNightService = services.DayNightService
	local BunicaService = services.BunicaService
	local SoulService = services.SoulService

	describe("Creaturile de suflet", function()
		it("un hoț nu poate ridica o creatură de suflet, dar poate ridica una obișnuită", function()
			DayNightService.forcePhase("Night")
			BunicaService.setEnabled(false)
			local victimBot = Actors.createBot("SufletBot", PlotService.plots[1].geometry.spawnCFrame)
			local victim = PlotService.assignBot(PlotService.plots[1], victimBot)
			local loved = Inventory.newRecord(victim.profile, victimBot.id, "Mamaligator", "Normal", nil)
			local plain = Inventory.newRecord(victim.profile, victimBot.id, "CartofelAgent", "Normal", nil)
			local lovedKey = select(2, Inventory.place(victim.profile, loved)) :: string
			local plainKey = select(2, Inventory.place(victim.profile, plain)) :: string
			CreatureService.render(victim)
			expect(SoulService.set(victim, loved.uid, true)).toBe(true)
			expect(CreatureService.modelAt(victim, lovedKey):GetAttribute("Soul")).toBe(true)

			local thief = Actors.createBot("HotSuflet", PlotService.plots[2].geometry.spawnCFrame)
			PlotService.assignBot(PlotService.plots[2], thief)
			local character = Actors.characterOf(thief) :: Model
			character:PivotTo(CreatureService.modelAt(victim, lovedKey):GetPivot() * CFrame.new(0, 0, -4))
			RaidService.tryStart(thief, victim, lovedKey)
			expect(RaidService.isCarrying(thief)).toBe(false)
			character:PivotTo(CreatureService.modelAt(victim, plainKey):GetPivot() * CFrame.new(0, 0, -4))
			RaidService.tryStart(thief, victim, plainKey)
			expect(RaidService.isCarrying(thief)).toBe(true)
			RaidService.drop(thief)
			Actors.removeBot(thief)
			Actors.removeBot(victimBot)
			BunicaService.setEnabled(true)
			DayNightService.forcePhase(nil)
		end)
	end)
end
