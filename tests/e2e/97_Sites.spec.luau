--!strict
-- Locurile satului (World/SiteBuilder): fiecare are modelul lui; centrul e zonă fără bătaie.

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Village = require(Shared.Config.Village)
local VillageLayout = require(Shared.Domain.VillageLayout)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local zonesModule = ServerScriptService.Server:WaitForChild("World"):FindFirstChild("Zones")
	local Zones = if zonesModule then (require :: any)(zonesModule) else nil
	local PlotService = services.PlotService
	local SlipperService = services.SlipperService

	describe("Locurile satului", function()
		it("fiecare loc are modelul lui, așezat pe teren, cu reperele cerute", function()
			local folder = Workspace:FindFirstChild("Village") and Workspace.Village:FindFirstChild("Sites")
			expect(folder ~= nil).toBe(true)
			for _, key in VillageLayout.SITE_KEYS do
				local model = (folder :: Instance):FindFirstChild(key)
				expect(model ~= nil and model:IsA("Model")).toBe(true)
				expect((model :: Model).PrimaryPart ~= nil).toBe(true)
			end
			local site = folder :: Instance
			for key, marker in
				{
					centru = "Tarc",
					terenScoala = "Culoar",
					lanPorumb = "Labirint",
					stana = "Tarc",
					gara = "Peron",
					iaz = "Debarcader",
					livada = "Matusa",
					moara = "Pale",
					biserica = "Clopot",
					codru = "Iesire",
					bazar = "Taraba8",
				} :: { [string]: string }
			do
				local holder = site:FindFirstChild(key)
				expect(holder ~= nil and holder:FindFirstChild(marker, true) ~= nil).toBe(true)
			end
		end)

		it("în centru nu se aruncă, dar cine cară o creatură furată tot poate fi lovit", function()
			expect(Zones ~= nil).toBe(true)
			expect(Zones.noFight(Village.hub + Vector3.new(0, 3, 0))).toBe(true)
			expect(Zones.noFight(PlotService.plots[1].geometry.cframe.Position)).toBe(false)
			local bot = Actors.createBot("CentruBot", PlotService.plots[5].geometry.spawnCFrame)
			PlotService.assignBot(PlotService.plots[5], bot)
			local character = Actors.characterOf(bot) :: Model
			character:PivotTo(CFrame.new(Village.hub + Vector3.new(4, 3, 4)))
			expect(SlipperService.throwAs(bot, Village.hub + Vector3.new(20, 3, 0), "Slipper")).toBe(false)
			character:PivotTo(PlotService.plots[5].geometry.spawnCFrame)
			expect(SlipperService.throwAs(bot, Village.hub, "Slipper")).toBe(true)
			Actors.removeBot(bot)
		end)
	end)
end
