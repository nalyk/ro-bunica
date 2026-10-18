--!strict
-- Decorul ogrăzii: cumperi pe lei, așezi pe slot (modelul apare), vopsești poarta, scoți; fără coliziuni.

local ServerScriptService = game:GetService("ServerScriptService")

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local DecorService = services.DecorService

	describe("Decorul ogrăzii", function()
		it("cumperi, așezi, vopsești poarta, scoți", function()
			local actor = Actors.createBot("Gospodar", PlotService.plots[6].geometry.spawnCFrame)
			local owner = PlotService.assignBot(PlotService.plots[6], actor)
			owner.profile.lei = 100000
			expect(DecorService.buy(owner, "felinar")).toBe(true)
			expect(DecorService.buy(owner, "poartaGalbena")).toBe(true)
			expect(DecorService.place(owner, "felinar", "s9")).toBe(false) -- felinarul nu stă pe gard
			expect(DecorService.place(owner, "felinar", "s1")).toBe(true)
			local folder = owner.plot.geometry.model:FindFirstChild("Decor")
			expect(folder ~= nil and folder:FindFirstChild("Decor_felinar") ~= nil).toBe(true)
			for _, part in (folder :: Instance):GetDescendants() do
				if part:IsA("BasePart") then
					expect(part.CanCollide).toBe(false)
				end
			end
			expect(DecorService.place(owner, "poartaGalbena", "s12")).toBe(true)
			local post = owner.plot.geometry.model:FindFirstChild("GatePost") :: BasePart
			expect(post.Color == Color3.fromRGB(220, 170, 50)).toBe(true)
			expect(DecorService.place(owner, nil, "s1")).toBe(true)
			expect((folder :: Instance):FindFirstChild("Decor_felinar") == nil).toBe(true)
			Actors.removeBot(actor)
		end)
	end)
end
