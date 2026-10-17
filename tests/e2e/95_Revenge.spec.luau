--!strict
-- Răzbunarea: A fură de la B; B își fură înapoi creatura în aceeași noapte și primește jumătate din preț în plus.

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Inventory = require(Shared.Domain.Inventory)
local Economy = require(Shared.Domain.Economy)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local CreatureService = services.CreatureService
	local RaidService = services.RaidService
	local SlipperService = services.SlipperService
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

	local function carryHome(actor: any, owner: any)
		local root = Actors.root(actor) :: BasePart
		local target = owner.plot.geometry.deposit.Position
		while RaidService.isCarrying(actor) do
			local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
			if flat.Magnitude < 1 then
				pump(0.3)
				break
			end
			local character = Actors.characterOf(actor) :: Model
			character:PivotTo(character:GetPivot() + flat.Unit * math.min(flat.Magnitude, 1))
			pump(0.1)
		end
	end

	local function standAt(actor: any, owner: any, key: string)
		local model = CreatureService.modelAt(owner, key) :: Model
		local character = Actors.characterOf(actor) :: Model
		character:PivotTo(model:GetPivot() * CFrame.new(0, 0, -4))
	end

	describe("Răzbunarea", function()
		it("victima își fură înapoi creatura până în zori și primește bonusul", function()
			DayNightService.forcePhase("Night")
			BunicaService.setEnabled(false)
			local botA = Actors.createBot("RazbunaA", PlotService.plots[3].geometry.spawnCFrame)
			local a = PlotService.assignBot(PlotService.plots[3], botA)
			local botB = Actors.createBot("RazbunaB", PlotService.plots[4].geometry.spawnCFrame)
			local b = PlotService.assignBot(PlotService.plots[4], botB)
			local record = Inventory.newRecord(b.profile, botB.id, "PepeneBoxer", "Normal", nil)
			local key = select(2, Inventory.place(b.profile, record)) :: string
			CreatureService.render(b)

			standAt(botA, b, key)
			RaidService.tryStart(botA, b, key)
			expect(RaidService.isCarrying(botA)).toBe(true)
			carryHome(botA, a)
			local stolenKey = Inventory.findPedestal(a.profile, record.uid)
			expect(stolenKey ~= nil).toBe(true)

			b.shieldUntil = 0 -- testul nu așteaptă scutul hoțului (A nu are scut: e NPC-bot)
			local before = b.profile.lei
			standAt(botB, a, stolenKey :: string)
			RaidService.tryStart(botB, a, stolenKey :: string)
			expect(RaidService.isCarrying(botB)).toBe(true)
			carryHome(botB, b)
			expect(Spec.waitFor(function()
				return b.profile.lei >= before + math.floor(Economy.sellPrice(record) / 2)
			end, 3)).toBe(true)
			Actors.removeBot(botA)
			Actors.removeBot(botB)
			BunicaService.setEnabled(true)
			DayNightService.forcePhase(nil)
		end)
	end)
end
