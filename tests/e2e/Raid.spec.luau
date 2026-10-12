--!strict
-- Furtul și papucul, jucate de boți în motorul Roblox real.
-- În sesiunile Open Cloud fizica nu rulează: boții sunt mutați cu PivotTo, în pași cu viteză plauzibilă.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Inventory = require(Shared.Domain.Inventory)
local ServerScriptService = game:GetService("ServerScriptService")

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local RaidService = services.RaidService
	local SlipperService = services.SlipperService
	local CreatureService = services.CreatureService
	local DayNightService = services.DayNightService
	local BunicaService = services.BunicaService

	-- Heartbeat poate lipsi fără fizică; atunci avansăm manual verificările și proiectilele.
	local heartbeats = 0
	local connection = RunService.Heartbeat:Connect(function()
		heartbeats += 1
	end)
	task.wait(0.3)
	connection:Disconnect()
	local manualPump = heartbeats == 0
	print("[e2e] pompare manuală: " .. tostring(manualPump))

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

	-- Mută botul spre țintă cu viteza dată (studs/s), pas cu pas.
	local function walk(actor: any, target: Vector3, speed: number)
		local root = Actors.root(actor) :: BasePart
		while true do
			local position = root.Position
			local flat = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
			if flat.Magnitude < 1 or not RaidService.isCarrying(actor) then
				return
			end
			local stepLength = math.min(flat.Magnitude, speed * 0.1)
			local character = Actors.characterOf(actor) :: Model
			character:PivotTo(character:GetPivot() + flat.Unit * stepLength)
			pump(0.1)
		end
	end

	local function firstPedestal(owner: any): string?
		for key in owner.profile.pedestals do
			return key
		end
		return nil
	end

	-- O ogradă cu un bot ca proprietar, cu o creatură expusă
	local function botPlot(index: number, name: string): (any, any)
		local plot = PlotService.plots[index]
		local bot = Actors.createBot(name, plot.geometry.spawnCFrame)
		local owner = PlotService.assignBot(plot, bot)
		local record = Inventory.newRecord(owner.profile, bot.id, "CartofelAgent", "Normal", nil)
		Inventory.place(owner.profile, record)
		CreatureService.render(owner)
		return bot, owner
	end

	local function standNear(actor: any, owner: any, key: string)
		local model = CreatureService.modelAt(owner, key) :: Model
		local character = Actors.characterOf(actor) :: Model
		character:PivotTo(model:GetPivot() * CFrame.new(0, 0, -4))
	end

	BunicaService.setEnabled(false)
	DayNightService.forcePhase("Night")

	describe("Furtul", function()
		it("un bot fură de la un vecin NPC și depune în beciul propriu", function()
			local thief, thiefOwner = botPlot(2, "HotBot")
			local victim = PlotService.plots[1].owner
			local key = firstPedestal(victim) :: string
			local uid = victim.profile.pedestals[key].uid
			standNear(thief, victim, key)
			RaidService.tryStart(thief, victim, key)
			expect(RaidService.isCarrying(thief)).toBe(true)
			expect(RaidService.isCarried(uid)).toBe(true)

			walk(thief, thiefOwner.plot.geometry.deposit.Position, 10)
			expect(Spec.waitFor(function()
				if manualPump then
					RaidService.checkCarries()
				end
				return not RaidService.isCarrying(thief)
			end, 3)).toBe(true)
			expect(victim.profile.pedestals[key] == nil).toBe(true)
			expect(Inventory.findPedestal(thiefOwner.profile, uid) ~= nil).toBe(true)
			expect(RaidService.isCarried(uid)).toBe(false)
			Actors.removeBot(thief)
		end)

		it("ziua nu se poate fura", function()
			DayNightService.forcePhase("Day")
			local thief = botPlot(3, "ZiBot")
			local victim = PlotService.plots[4].owner
			local key = firstPedestal(victim) :: string
			standNear(thief, victim, key)
			RaidService.tryStart(thief, victim, key)
			expect(RaidService.isCarrying(thief)).toBe(false)
			Actors.removeBot(thief)
			DayNightService.forcePhase("Night")
		end)

		it("un teleport anulează furtul, iar creatura rămâne proprietarului", function()
			local thief = botPlot(5, "TeleportBot")
			local victim = PlotService.plots[6].owner
			local key = firstPedestal(victim) :: string
			local uid = victim.profile.pedestals[key].uid
			standNear(thief, victim, key)
			RaidService.tryStart(thief, victim, key)
			expect(RaidService.isCarrying(thief)).toBe(true)
			local character = Actors.characterOf(thief) :: Model
			character:PivotTo(character:GetPivot() + Vector3.new(120, 0, 0))
			pump(1)
			expect(RaidService.isCarrying(thief)).toBe(false)
			expect(victim.profile.pedestals[key].uid).toBe(uid)
			Actors.removeBot(thief)
		end)
	end)

	describe("Papucul", function()
		it("proprietarul îl lovește pe hoț, iar creatura se întoarce pe piedestal", function()
			local defender, defenderOwner = botPlot(7, "BunicBot")
			local thief = botPlot(8, "HotLovitBot")
			local key = firstPedestal(defenderOwner) :: string
			local uid = defenderOwner.profile.pedestals[key].uid
			standNear(thief, defenderOwner, key)
			RaidService.tryStart(thief, defenderOwner, key)
			expect(RaidService.isCarrying(thief)).toBe(true)

			-- Apărătorul stă la 15 studs și aruncă spre hoț
			local thiefRoot = Actors.root(thief) :: BasePart
			local defenderCharacter = Actors.characterOf(defender) :: Model
			defenderCharacter:PivotTo(CFrame.new(thiefRoot.Position + Vector3.new(15, 0, 0)))
			expect(SlipperService.throwAs(defender, thiefRoot.Position, "Slipper")).toBe(true)
			pump(1.5)
			expect(RaidService.isCarrying(thief)).toBe(false)
			expect(RaidService.isStunned(thief)).toBe(true)
			expect(defenderOwner.profile.pedestals[key].uid).toBe(uid)
			expect(defenderOwner.profile.stats.defends).toBe(1)
			expect(SlipperService.nervi(defender) > 0).toBe(true)
			Actors.removeBot(thief)
			Actors.removeBot(defender)
		end)

		it("muniția se termină după 3 aruncări", function()
			local defender = botPlot(7, "MunitieBot")
			local root = Actors.root(defender) :: BasePart
			local target = root.Position + Vector3.new(0, 0, -20)
			expect(SlipperService.throwAs(defender, target, "Slipper")).toBe(true)
			expect(SlipperService.throwAs(defender, target, "Slipper")).toBe(true)
			expect(SlipperService.throwAs(defender, target, "Slipper")).toBe(true)
			expect(SlipperService.throwAs(defender, target, "Slipper")).toBe(false)
			Actors.removeBot(defender)
		end)
	end)

	describe("Bunica NPC", function()
		it("îl observă pe hoț și aruncă singură când proprietarul lipsește", function()
			BunicaService.setEnabled(true)
			local thief = botPlot(2, "PrinsBot")
			local victim = PlotService.plots[1].owner
			local key = firstPedestal(victim) :: string
			standNear(thief, victim, key)
			RaidService.tryStart(thief, victim, key)
			expect(RaidService.isCarrying(thief)).toBe(true)
			-- Hoțul stă pe loc: bănuiala crește (~3 s), apoi avertisment (0,6 s) și papucul lent
			local hit = Spec.waitFor(function()
				if manualPump then
					SlipperService.step(0.1)
					RaidService.checkCarries()
				end
				return not RaidService.isCarrying(thief)
			end, 12)
			expect(hit).toBe(true)
			Actors.removeBot(thief)
			BunicaService.setEnabled(false)
		end)
	end)

	DayNightService.forcePhase(nil)
end
