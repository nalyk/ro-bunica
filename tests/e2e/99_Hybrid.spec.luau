--!strict
-- Hibrizii: două straturi vecine cu creaturi rare; la eclozare (șansa forțată), hibridul are nume, „pălărie”,
-- venit (A + B) × 0,75 și intrare în colecția de hibrizi.

local ServerScriptService = game:GetService("ServerScriptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Growth = require(Shared.Domain.Growth)
local Hybrid = require(Shared.Domain.Hybrid)
local Economy = require(Shared.Domain.Economy)
local Inventory = require(Shared.Domain.Inventory)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local GardenService = services.GardenService
	local CreatureService = services.CreatureService

	describe("Hibrizii", function()
		it(
			"eclozarea forțată lângă un vecin rar dă un hibrid cu nume, pălărie și venit (A + B) × 0,75",
			function()
				local rares = {}
				for _, c in Creatures.list do
					if c.rarity == "Rare" then
						table.insert(rares, c.id)
					end
				end
				local a, b = rares[1], rares[2] or rares[1]
				local actor = Actors.createBot("Hibridar", PlotService.plots[6].geometry.spawnCFrame)
				local owner = PlotService.assignBot(PlotService.plots[6], actor)
				GardenService.setHybridChance(1)
				local ready = Growth.newPlant(a, math.random)
				ready.grown = Growth.requiredSeconds(ready)
				owner.profile.beds["1"] = ready
				owner.profile.beds["2"] = Growth.newPlant(b, math.random) -- vecinul, încă în creștere
				expect(Spec.waitFor(function()
					return owner.profile.beds["1"] == nil
				end, 5)).toBe(true)
				GardenService.setHybridChance(nil)
				local record
				for _, r in owner.profile.pedestals do
					if r.id == a then
						record = r
					end
				end
				expect(record ~= nil and record.hybrid == b).toBe(true)
				expect(record.hybridName).toBe(Hybrid.name(a, b, owner.profile.uidCounter))
				expect(owner.profile.hybrids[Hybrid.key(a, b)]).toBe(true)
				local plain =
					Economy.incomePerSecond({ id = a, size = record.size, mutation = record.mutation })
				local mixed = Economy.incomePerSecond(record)
				expect(mixed > plain * 0.9).toBe(true)
				local key = Inventory.findPedestal(owner.profile, record.uid) :: string
				local model = CreatureService.modelAt(owner, key) :: Model
				expect(model:GetAttribute("Hybrid")).toBe(b)
				Actors.removeBot(actor)
			end
		)
	end)
end
