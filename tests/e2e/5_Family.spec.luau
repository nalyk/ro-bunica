--!strict
-- Familia (fără furt între membri, apărare reciprocă) și ritualul Horei.

local ServerScriptService = game:GetService("ServerScriptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Inventory = require(Shared.Domain.Inventory)
local Hora = require(Shared.Config.Hora)
local GameState = require(Shared.GameState)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local CreatureService = services.CreatureService
	local SlipperService = services.SlipperService
	local RaidService = services.RaidService
	local FamilyService = services.FamilyService
	local HoraService = services.HoraService
	local DayNightService = services.DayNightService
	local BunicaService = services.BunicaService

	local function botOwner(index: number, name: string): (any, any)
		local plot = PlotService.plots[index]
		local bot = Actors.createBot(name, plot.geometry.spawnCFrame)
		local owner = PlotService.assignBot(plot, bot)
		Inventory.place(
			owner.profile,
			Inventory.newRecord(owner.profile, bot.id, "CartofelAgent", "Normal", nil)
		)
		CreatureService.render(owner)
		return bot, owner
	end

	local function firstKey(owner: any): string
		local key = next(owner.profile.pedestals)
		return key :: string
	end

	describe("Familia", function()
		DayNightService.forcePhase("Night")
		BunicaService.setEnabled(false)

		it("membrii familiei nu-și fură între ei și nu sunt intruși", function()
			local a, ownerA = botOwner(1, "FratA")
			local b = botOwner(2, "FratB")
			FamilyService.setFamily(a, 77)
			FamilyService.setFamily(b, 77)
			local key = firstKey(ownerA)
			local model = CreatureService.modelAt(ownerA, key) :: Model
			(Actors.characterOf(b) :: Model):PivotTo(model:GetPivot() * CFrame.new(0, 0, -4))
			expect(RaidService.isIntruder(b, ownerA)).toBe(false)
			RaidService.tryStart(b, ownerA, key)
			expect(RaidService.isCarrying(b)).toBe(false)
			Actors.removeBot(a)
			Actors.removeBot(b)
		end)

		it("un membru apără ograda altui membru cu papucul", function()
			local a, ownerA = botOwner(3, "GazdaBot")
			local b = botOwner(4, "VarBot")
			FamilyService.setFamily(a, 88)
			FamilyService.setFamily(b, 88)
			local thief =
				Actors.createBot("StrainBot", ownerA.plot.geometry.spawnCFrame * CFrame.new(8, 0, 0))
			expect(RaidService.isIntruder(thief, ownerA)).toBe(true)
			local thiefRoot = Actors.root(thief) :: BasePart
			(Actors.characterOf(b) :: Model):PivotTo(CFrame.new(thiefRoot.Position + Vector3.new(15, 0, 0)))
			expect(SlipperService.throwAs(b, thiefRoot.Position, "Slipper")).toBe(true)
			expect(Spec.waitFor(function()
				return RaidService.isStunned(thief)
			end, 3)).toBe(true)
			Actors.removeBot(thief)
			Actors.removeBot(a)
			Actors.removeBot(b)
		end)

		DayNightService.forcePhase(nil)
	end)

	describe("Hora", function()
		it("trei dansatori în vatră cheamă o vreme rară", function()
			HoraService.resetCooldown()
			local bots = {}
			for i = 1, 3 do
				local angle = i * math.pi * 2 / 3
				local position = Hora.center + Vector3.new(math.cos(angle) * 6, 3, math.sin(angle) * 6)
				local bot = Actors.createBot("Dansator" .. i, CFrame.new(position))
				HoraService.setDancing(bot, 15)
				table.insert(bots, bot)
			end
			expect(Spec.waitFor(function()
				local weather = GameState.get("Weather")
				return weather == "GoldHarvest" or weather == "Rainbow"
			end, 8)).toBe(true)
			expect(HoraService.readyAt()).toBeGreaterThan(0)
			for _, bot in bots do
				Actors.removeBot(bot)
			end
		end)
	end)
end
