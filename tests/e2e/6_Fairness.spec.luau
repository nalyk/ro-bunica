--!strict
-- Furt corect: limita de furturi pe noapte și recompensa pentru apărare.

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Inventory = require(Shared.Domain.Inventory)
local Economy = require(Shared.Domain.Economy)
local Raid = require(Shared.Domain.Raid)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local CreatureService = services.CreatureService
	local SlipperService = services.SlipperService
	local RaidService = services.RaidService
	local DayNightService = services.DayNightService
	local BunicaService = services.BunicaService

	local heartbeats = 0
	local connection = RunService.Heartbeat:Connect(function()
		heartbeats += 1
	end)
	task.wait(0.3)
	connection:Disconnect()
	local manualPump = heartbeats == 0

	local function pump(seconds: number)
		local deadline = os.clock() + seconds
		while os.clock() < deadline do
			local dt = task.wait(0.05)
			if manualPump then
				RaidService.checkCarries()
				SlipperService.step(dt)
			end
		end
	end

	local function walk(actor: any, target: Vector3)
		local character = Actors.characterOf(actor) :: Model
		local root = Actors.root(actor) :: BasePart
		while RaidService.isCarrying(actor) do
			local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
			if flat.Magnitude < 1 then
				break
			end
			character:PivotTo(character:GetPivot() + flat.Unit * math.min(flat.Magnitude, 1))
			pump(0.1)
		end
		pump(0.3)
	end

	local function owner(index: number, name: string, creatures: number): (any, any)
		local plot = PlotService.plots[index]
		local bot = Actors.createBot(name, plot.geometry.spawnCFrame)
		local state = PlotService.assignBot(plot, bot)
		for _ = 1, creatures do
			Inventory.place(
				state.profile,
				Inventory.newRecord(state.profile, bot.id, "CartofelAgent", "Normal", nil)
			)
		end
		CreatureService.render(state)
		return bot, state
	end

	local function stealOnce(thief: any, thiefState: any, victim: any): boolean
		local key = next(victim.profile.pedestals) :: string
		local model = CreatureService.modelAt(victim, key) :: Model
		(Actors.characterOf(thief) :: Model):PivotTo(model:GetPivot() * CFrame.new(0, 0, -4))
		RaidService.tryStart(thief, victim, key)
		if not RaidService.isCarrying(thief) then
			return false
		end
		walk(thief, thiefState.plot.geometry.deposit.Position)
		return not RaidService.isCarrying(thief)
	end

	DayNightService.forcePhase("Night")
	BunicaService.setEnabled(false)

	describe("Furt corect", function()
		it("după 2 furturi reușite, ograda e protejată până dimineață", function()
			local _victimBot, victim = owner(1, "VictimaBot", 4)
			local thief, thiefState = owner(2, "LacomBot", 0)
			expect(stealOnce(thief, thiefState, victim)).toBe(true)
			expect(stealOnce(thief, thiefState, victim)).toBe(true)
			expect(victim.stolenTonight).toBe(2)
			expect(stealOnce(thief, thiefState, victim)).toBe(false)
			DayNightService.forcePhase("Day")
			task.wait(0.2)
			expect(victim.stolenTonight).toBe(0)
			DayNightService.forcePhase("Night")
			Actors.removeBot(thief)
			Actors.removeBot(_victimBot)
		end)

		it("cine salvează creatura primește jumătate din prețul ei", function()
			local defender, defenderState = owner(3, "PazaBot", 1)
			local thief, thiefState = owner(4, "PrinsBot2", 0)
			local key = next(defenderState.profile.pedestals) :: string
			local record = defenderState.profile.pedestals[key]
			local model = CreatureService.modelAt(defenderState, key) :: Model
			(Actors.characterOf(thief) :: Model):PivotTo(model:GetPivot() * CFrame.new(0, 0, -4))
			RaidService.tryStart(thief, defenderState, key)
			expect(RaidService.isCarrying(thief)).toBe(true)
			local leiBefore = defenderState.profile.lei
			local thiefRoot = Actors.root(thief) :: BasePart
			(Actors.characterOf(defender) :: Model):PivotTo(
				CFrame.new(thiefRoot.Position + Vector3.new(12, 0, 0))
			)
			expect(SlipperService.throwAs(defender, thiefRoot.Position, "Slipper")).toBe(true)
			local expected = Raid.defenseReward(Economy.sellPrice(record))
			expect(Spec.waitFor(function()
				return defenderState.profile.lei >= leiBefore + expected
			end, 3)).toBe(true)
			local _ = thiefState
			Actors.removeBot(thief)
			Actors.removeBot(defender)
		end)
	end)

	DayNightService.forcePhase(nil)
end
