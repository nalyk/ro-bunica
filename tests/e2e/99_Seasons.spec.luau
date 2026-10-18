--!strict
-- Sărbătorile, impuse: ouăle de Paște, hramul (nu se fură), colinda și masca de Malanca, Mărțișorul, știuletele.

local ServerScriptService = game:GetService("ServerScriptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameState = require(Shared.GameState)
local Inventory = require(Shared.Domain.Inventory)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local SeasonService = services.SeasonService
	local RaidService = services.RaidService
	local CreatureService = services.CreatureService
	local BunicaService = services.BunicaService
	local GardenService = services.GardenService

	local function bot(name: string, index: number): (any, any)
		local actor = Actors.createBot(name, PlotService.plots[index].geometry.spawnCFrame)
		return actor, PlotService.assignBot(PlotService.plots[index], actor)
	end

	describe("Sărbătorile", function()
		it("Paștele: ouăle apar prin sat; cine trece pe lângă unul îl ia", function()
			SeasonService.force({ "Paste" })
			expect(GameState.get(GameState.Attributes.Holidays)).toBe("Paste")
			expect(Spec.waitFor(function()
				return #SeasonService.eggs() >= SeasonService.EGGS
			end, 4)).toBe(true)
			local actor, owner = bot("Oua", 6)
			local before = 0
			for _, n in owner.profile.eggs do
				before += n
			end
			(Actors.characterOf(actor) :: Model):PivotTo(
				CFrame.new(SeasonService.eggs()[1].Position + Vector3.new(0, 2, 0))
			)
			expect(Spec.waitFor(function()
				local total = 0
				for _, n in owner.profile.eggs do
					total += n
				end
				return total > before
			end, 4)).toBe(true)
			Actors.removeBot(actor)
		end)

		it("Mărțișorul grăbește straturile; Culesul ascunde știuletele roșu", function()
			SeasonService.force({ "Martisor", "Culesul" })
			expect(GardenService.seasonFactor).toBe(1.2)
			expect(#SeasonService.eggs()).toBe(0) -- Paștele s-a terminat: ouăle au dispărut
			expect(Spec.waitFor(function()
				return SeasonService.cob() ~= nil
			end, 4)).toBe(true)
		end)

		it("hramul: casă deschisă, furtul e refuzat", function()
			SeasonService.force({ "Hram" })
			BunicaService.setEnabled(false)
			local victimBot, victim = bot("Gazda", 2)
			local record = Inventory.newRecord(victim.profile, victimBot.id, "CartofelAgent", "Normal", nil)
			local key = select(2, Inventory.place(victim.profile, record)) :: string
			CreatureService.render(victim)
			local thief = bot("Oaspete", 3);
			(Actors.characterOf(thief) :: Model):PivotTo(
				CreatureService.modelAt(victim, key):GetPivot() * CFrame.new(0, 0, -4)
			)
			RaidService.tryStart(thief, victim, key)
			expect(RaidService.isCarrying(thief)).toBe(false)
			Actors.removeBot(thief)
			Actors.removeBot(victimBot)
			BunicaService.setEnabled(true)
		end)

		it("Drăgaica: coronița se aruncă o singură dată pe zi", function()
			SeasonService.force({ "Dragaica" })
			local actor, owner = bot("Coronita", 6)
			SeasonService.act(owner, "crown")
			expect(SeasonService.act(owner, "crown")).toBe(false)
			Actors.removeBot(actor)
		end)

		it(
			"Iarna: colinda la poarta unui vecin NPC dă un colac o dată; masca o ascunde de Bunica",
			function()
				SeasonService.force({ "Iarna" })
				local actor, owner = bot("Colindator", 6)
				local npcPlot = nil
				for _, plot in PlotService.plots do
					if plot.owner and plot.owner.kind == "Npc" and not plot.owner.standIn then
						npcPlot = plot
						break
					end
				end
				if npcPlot then
					local gate = (npcPlot.geometry.cframe * CFrame.new(0, 3, -35)).Position;
					(Actors.characterOf(actor) :: Model):PivotTo(CFrame.new(gate))
					local lei = owner.profile.lei
					expect(SeasonService.act(owner, "colinda")).toBe(true)
					expect(owner.profile.lei - lei).toBe(SeasonService.COLAC_LEI)
					expect(SeasonService.act(owner, "colinda")).toBe(false)
				else
					print("⚠ [Seasons] niciun vecin NPC pe server: colinda nu s-a putut verifica")
				end
				expect(SeasonService.act(owner, "mask")).toBe(true)
				expect(BunicaService.isDisguised(actor)).toBe(true)
				expect(SeasonService.act(owner, "mask")).toBe(false) -- o dată la 5 minute
				Actors.removeBot(actor)
				SeasonService.force(nil)
			end
		)
	end)
end
