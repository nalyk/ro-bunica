--!strict
-- Bunica-vedetă: replicile și starea de sărbătoare la loviturile din ograda ei.

local ServerScriptService = game:GetService("ServerScriptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Inventory = require(Shared.Domain.Inventory)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local CreatureService = services.CreatureService
	local SlipperService = services.SlipperService
	local RaidService = services.RaidService

	describe("Bunica", function()
		it("după o lovitură în ograda ei sărbătorește și spune o replică", function()
			local plot = PlotService.plots[6]
			local defender = Actors.createBot("NepotBot", plot.geometry.spawnCFrame)
			local owner = PlotService.assignBot(plot, defender)
			Inventory.place(
				owner.profile,
				Inventory.newRecord(owner.profile, defender.id, "CartofelAgent", "Normal", nil)
			)
			CreatureService.render(owner)
			local thief = Actors.createBot("HotPrinsBot", plot.geometry.spawnCFrame * CFrame.new(10, 0, 0))
			RaidService.forceIntruder(thief, owner)
			local rig = plot.geometry.model:FindFirstChild("Bunica") :: Model
			local seqBefore = (rig:GetAttribute("LineSeq") :: number?) or 0
			local thiefRoot = Actors.root(thief) :: BasePart
			expect(SlipperService.throwAs(defender, thiefRoot.Position, "Slipper")).toBe(true)
			expect(Spec.waitFor(function()
				return rig:GetAttribute("Mood") == "Celebrate"
			end, 3)).toBe(true)
			expect(((rig:GetAttribute("LineSeq") :: number?) or 0) > seqBefore).toBe(true)
			local line = rig:GetAttribute("Line")
			expect(type(line) == "string" and string.find(line :: string, "bunica.hit", 1, true) ~= nil).toBe(
				true
			)
			RaidService.forceIntruder(thief, nil)
			Actors.removeBot(thief)
			Actors.removeBot(defender)
		end)
	end)
end
