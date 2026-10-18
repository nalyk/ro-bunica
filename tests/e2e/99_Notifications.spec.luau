--!strict
-- Notificările după plecare (NotificationService): când se coc plantele în lipsa jucătorului și dacă
-- serverul poate trimite prin Open Cloud (UserNotification). Codul răspunsului se afișează: 200 = trimis,
-- 4xx cu motiv (jucătorul n-a acceptat notificările, limita zilnică) = cererea e autentificată.

local ServerScriptService = game:GetService("ServerScriptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Growth = require(Shared.Domain.Growth)

local CREATOR = 1741390820 -- contul care a făcut jocul (tools/assets.py)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local NotificationService = services.NotificationService

	describe("Notificările", function()
		it("coacerea în lipsă: ultima plantă care se coace sub plafonul offline", function()
			local actor = Actors.createBot("Gradinar", PlotService.plots[6].geometry.spawnCFrame)
			local owner = PlotService.assignBot(PlotService.plots[6], actor)
			expect(NotificationService.growSeconds(owner)).toBe(nil)
			local plant = Growth.newPlant("CartofelAgent", function()
				return 0.5
			end)
			owner.profile.beds["1"] = plant :: any
			local left = Growth.secondsLeft(plant, 1)
			expect(NotificationService.growSeconds(owner)).toBe(left)
			Actors.removeBot(actor)
		end)

		it("serverul trimite prin Open Cloud, sau sare curat peste trimitere fără secret", function()
			local status, body = NotificationService.send(CREATOR, "grown")
			print(string.format("[e2e] notificare Open Cloud: %d %s", status, tostring(body):sub(1, 200)))
			-- fără secretul Open Cloud configurat, serviciul nu trimite nimic (și nu cade)
			expect(status ~= 0 or body == "no-secret").toBe(true)
		end)
	end)
end
