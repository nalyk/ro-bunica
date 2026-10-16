--!strict
-- Îmbunătățirile ogrăzii pe serverul real: prețul se scade, piedestalul nou se deblochează în ogradă,
-- Grivei încetinește hoțul din ogradă și îi dă viteza înapoi când iese.

local ServerScriptService = game:GetService("ServerScriptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Upgrades = require(Shared.Domain.Upgrades)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local UpgradeService = services.UpgradeService
	local RaidService = services.RaidService
	local DayNightService = services.DayNightService

	describe("Îmbunătățiri", function()
		it("piedestalul cumpărat cu lei se deblochează în ogradă", function()
			local plot = PlotService.plots[7]
			local bot = Actors.createBot("Gospodar", plot.geometry.spawnCFrame)
			local owner = PlotService.assignBot(plot, bot)
			owner.profile.lei = 1000
			local before = owner.profile.pedestalCount
			local key = tostring(before + 1)
			local pedestal = plot.geometry.pedestals[key]
			local link = pedestal:FindFirstChild("Art") :: ObjectValue?
			local function faded(): boolean
				local art = link and link.Value
				local part = art and art:FindFirstChildWhichIsA("BasePart", true)
				return if part then (part :: BasePart).Transparency > 0.5 else pedestal.Transparency > 0.5
			end
			expect(faded()).toBe(true)
			expect(UpgradeService.buy(owner, "pedestal")).toBe("ok")
			expect(owner.profile.lei).toBe(850)
			expect(owner.profile.pedestalCount).toBe(before + 1)
			expect(faded()).toBe(false)
			owner.profile.lei = 0
			expect(UpgradeService.buy(owner, "pedestal")).toBe("lei")
			Actors.removeBot(bot)
		end)

		it("Grivei încetinește hoțul din ogradă și îi dă viteza înapoi când pleacă", function()
			DayNightService.forcePhase("Night")
			local plot = PlotService.plots[8]
			local ownerBot = Actors.createBot("StapanCuCaine", plot.geometry.spawnCFrame)
			local owner = PlotService.assignBot(plot, ownerBot)
			owner.profile.lei = 10 ^ 6
			expect(UpgradeService.buy(owner, "dog")).toBe("ok")
			local thief = Actors.createBot("HotLatrat", plot.geometry.spawnCFrame * CFrame.new(6, 0, 0))
			local humanoid = Actors.humanoid(thief) :: Humanoid
			local base = humanoid.WalkSpeed
			expect(RaidService.isIntruder(thief, owner)).toBe(true)
			RaidService.checkDogs()
			expect(math.abs(humanoid.WalkSpeed - base * Upgrades.dogSlow(owner.profile)) < 1e-6).toBe(true)
			-- iese pe drum
			local character = Actors.characterOf(thief) :: Model
			character:PivotTo(plot.geometry.cframe * CFrame.new(0, 3, -80))
			RaidService.checkDogs()
			expect(humanoid.WalkSpeed).toBe(base)
			Actors.removeBot(thief)
			Actors.removeBot(ownerBot)
			DayNightService.forcePhase(nil)
		end)
	end)
end
