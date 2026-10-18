--!strict
-- Rutiera: botul urcă lângă microbuz, își alege stația și coboară singur acolo; cu creatura furată nu urcă.

local ServerScriptService = game:GetService("ServerScriptService")

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local RutieraService = services.RutieraService

	describe("Rutiera", function()
		it("botul urcă, alege ograda 3 și coboară lângă poarta ei", function()
			expect(RutieraService ~= nil).toBe(true)
			local vehicle = RutieraService.vehicle() :: Model
			local bot = Actors.createBot("Calator", vehicle:GetPivot() * CFrame.new(8, 0, 0))
			task.wait(0.1)
			local character = Actors.characterOf(bot) :: Model
			character:PivotTo(vehicle:GetPivot() * CFrame.new(Vector3.new(7, 0, 0)))
			expect(RutieraService.board(bot)).toBe(true)
			expect(RutieraService.isRiding(bot)).toBe(true)
			expect(RutieraService.alight(bot, "plot3")).toBe(true)
			-- sare în timp până chiar înainte de sosire
			RutieraService.warp(RutieraService.secondsTo("plot3") - 1)
			expect(Spec.waitFor(function()
				return not RutieraService.isRiding(bot)
			end, 6)).toBe(true)
			local gate = PlotService.plots[3].geometry.cframe * CFrame.new(0, 0, -35)
			local root = Actors.root(bot) :: BasePart
			local flat = Vector3.new(root.Position.X - gate.X, 0, root.Position.Z - gate.Z)
			expect(flat.Magnitude < 30).toBe(true)
			Actors.removeBot(bot)
		end)

		it("departe de rutieră nu urci", function()
			local vehicle = RutieraService.vehicle() :: Model
			local bot = Actors.createBot("Departe", vehicle:GetPivot() * CFrame.new(80, 0, 0))
			task.wait(0.1)
			expect(RutieraService.board(bot)).toBe(false)
			Actors.removeBot(bot)
		end)
	end)
end
