--!strict
-- Vecinii hoți: botul unui vecin NPC fură noaptea după regulile furtului de la jucători.
-- Fără fizică (Open Cloud), botul e mutat în pași cu viteză plauzibilă de un „mover” de test.

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Inventory = require(Shared.Domain.Inventory)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local RaidService = services.RaidService
	local SlipperService = services.SlipperService
	local CreatureService = services.CreatureService
	local DayNightService = services.DayNightService
	local BunicaService = services.BunicaService
	local NpcThiefService = services.NpcThiefService

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

	-- Mută botul spre punct cu 10 studs/s (sub viteza cu creatura în brațe), cât shouldStop nu cere oprirea
	local function stepMover(actor: any, point: Vector3, shouldStop: () -> boolean): boolean
		local root = Actors.root(actor)
		while root and actor.alive and not shouldStop() do
			local flat = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
			if flat.Magnitude < 1 then
				return true
			end
			local character = Actors.characterOf(actor) :: Model
			character:PivotTo(character:GetPivot() + flat.Unit * math.min(flat.Magnitude, 1))
			pump(0.1)
		end
		return false
	end

	-- O ogradă de „jucător” (bot) cu un Epic și un Legendar expuse
	local function victimPlot(index: number, name: string): (any, any)
		local plot = PlotService.plots[index]
		local bot = Actors.createBot(name, plot.geometry.spawnCFrame)
		local owner = PlotService.assignBot(plot, bot)
		Inventory.place(
			owner.profile,
			Inventory.newRecord(owner.profile, bot.id, "BranzoiSumo", "Normal", nil)
		)
		Inventory.place(
			owner.profile,
			Inventory.newRecord(owner.profile, bot.id, "Mamaligator", "Normal", nil)
		)
		CreatureService.render(owner)
		return bot, owner
	end

	local function uidOf(owner: any, id: string): string?
		for _, record in owner.profile.pedestals do
			if record.id == id then
				return record.uid
			end
		end
		return nil
	end

	local function neighbourExcept(index: number): any
		for _, plot in PlotService.plots do
			local owner = plot.owner
			if plot.index ~= index and owner and owner.kind == "Npc" and owner.actor == nil then
				return owner
			end
		end
		return nil
	end

	describe("Vecinii hoți", function()
		NpcThiefService.setEnabled(false) -- fără nopți programate; testele pornesc încercările direct
		BunicaService.setEnabled(false)
		DayNightService.forcePhase("Night")

		it("fură cel mai valoros Epic (nu Legendarul) și îl duce pe piedestalul vecinului", function()
			local owner, victim = victimPlot(1, "VictimaBot")
			local npc = neighbourExcept(1)
			expect(npc ~= nil).toBe(true)
			local epic = uidOf(victim, "Mamaligator") :: string
			local legendary = uidOf(victim, "BranzoiSumo") :: string
			-- vecinul are toate piedestalele pline: creatura furată tot pe piedestal trebuie să ajungă
			while Inventory.freePedestal(npc.profile) do
				Inventory.place(
					npc.profile,
					Inventory.newRecord(npc.profile, npc.userId, "CartofelAgent", "Normal", nil)
				)
			end
			local outcome = NpcThiefService.attempt(victim, npc, stepMover)
			expect(outcome).toBe("Stolen")
			expect(Inventory.findPedestal(npc.profile, epic) ~= nil).toBe(true)
			expect(Inventory.findPedestal(victim.profile, epic) == nil).toBe(true)
			-- se poate fura înapoi: modelul de la vecin are prompt-ul de furt, chiar pe creatură
			local stolenKey = Inventory.findPedestal(npc.profile, epic) :: string
			local stolenModel = CreatureService.modelAt(npc, stolenKey)
			expect(stolenModel ~= nil).toBe(true)
			task.wait(0.2)
			local prompt = stolenModel and stolenModel:FindFirstChildWhichIsA("ProximityPrompt", true)
			print(
				"[e2e] prompt furt înapoi:",
				prompt and prompt:GetFullName(),
				stolenModel and stolenModel.PrimaryPart
			)
			expect(prompt ~= nil).toBe(true)
			expect(Inventory.findPedestal(victim.profile, legendary) ~= nil).toBe(true)
			expect(victim.stolenTonight).toBe(1)
			-- botul pleacă, iar vecinul (cu creatura furată) rămâne pe loc
			expect(Spec.waitFor(function()
				return npc.actor == nil
			end, 20)).toBe(true)
			expect(npc.plot.owner == npc).toBe(true)
			expect(Inventory.findPedestal(npc.profile, epic) ~= nil).toBe(true)
			Actors.removeBot(owner)
		end)

		it("proprietarul îl doboară cu papucul și creatura rămâne acasă", function()
			local owner, victim = victimPlot(2, "ApararBot")
			local npc = neighbourExcept(2)
			local epic = uidOf(victim, "Mamaligator") :: string
			local outcome: string? = nil
			task.spawn(function()
				outcome = NpcThiefService.attempt(victim, npc, function(actor, point, shouldStop)
					-- cu creatura în brațe merge încet, ca apărătorul să aibă timp să arunce
					if RaidService.isCarrying(actor) then
						pump(3)
					end
					return stepMover(actor, point, shouldStop)
				end)
			end)
			expect(Spec.waitFor(function()
				return npc.actor ~= nil and RaidService.isCarrying(npc.actor)
			end, 20)).toBe(true)
			local thiefRoot = Actors.root(npc.actor) :: BasePart
			local character = Actors.characterOf(owner) :: Model
			character:PivotTo(CFrame.new(thiefRoot.Position + Vector3.new(15, 0, 0)))
			expect(SlipperService.throwAs(owner, thiefRoot.Position, "Slipper")).toBe(true)
			expect(Spec.waitFor(function()
				return outcome ~= nil
			end, 20)).toBe(true)
			expect(outcome).toBe("Hit")
			expect(Inventory.findPedestal(victim.profile, epic) ~= nil).toBe(true)
			expect(victim.profile.stats.defends).toBe(1)
			Spec.waitFor(function()
				return npc.actor == nil
			end, 20)
			Actors.removeBot(owner)
		end)

		it("fără creaturi până la Epic nu vine nimeni", function()
			local owner, victim = victimPlot(3, "BogatBot")
			for key, record in victim.profile.pedestals do
				if record.id == "Mamaligator" then
					Inventory.takeFromPedestal(victim.profile, key)
				end
			end
			CreatureService.render(victim)
			expect(NpcThiefService.attempt(victim, neighbourExcept(3), stepMover)).toBe("NoTarget")
			Actors.removeBot(owner)
		end)

		DayNightService.forcePhase(nil)
		BunicaService.setEnabled(true)
		NpcThiefService.setEnabled(true)
	end)
end
