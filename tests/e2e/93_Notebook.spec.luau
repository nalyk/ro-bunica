--!strict
-- Caietul Bunicii (renașterea, treburile) și schimburile, jucate de boți cu ogradă în motorul Roblox real.

local ServerScriptService = game:GetService("ServerScriptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Inventory = require(Shared.Domain.Inventory)
local Notebook = require(Shared.Config.Notebook)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local CreatureService = services.CreatureService
	local DayNightService = services.DayNightService
	local NotebookService = services.NotebookService
	local TradeService = services.TradeService
	local Quests = require(Shared.Domain.Quests)
	local Daily = require(Shared.Domain.Daily)

	local function botOwner(index: number, name: string): (any, any)
		local plot = PlotService.plots[index]
		local bot = Actors.createBot(name, plot.geometry.spawnCFrame)
		return bot, PlotService.assignBot(plot, bot)
	end

	describe("Caietul Bunicii", function()
		it("renașterea: costă leii, păstrează creatura de suflet, dă steluța și sămânța", function()
			DayNightService.forcePhase("Day")
			local bot, owner = botOwner(1, "RenascutBot")
			local profile = owner.profile
			Inventory.place(profile, Inventory.newRecord(profile, bot.id, "CartofelAgent", "Normal", nil))
			local best = Inventory.newRecord(profile, bot.id, "PepeneBoxer", "Huge", "Golden")
			Inventory.place(profile, best)
			CreatureService.render(owner)
			profile.lei = 999999
			expect(NotebookService.rebirth(owner)).toBe(false)
			profile.lei = 1000000
			DayNightService.forcePhase("Night")
			expect(NotebookService.rebirth(owner)).toBe(false) -- doar ziua
			DayNightService.forcePhase("Day")
			expect(NotebookService.rebirth(owner)).toBe(true)
			expect(profile.rebirths).toBe(1)
			expect(profile.lei).toBe(60)
			expect(profile.pedestals["1"].uid).toBe(best.uid)
			expect(profile.pedestals["2"] == nil).toBe(true)
			expect(profile.seeds[Notebook.rebirth.giftSeed]).toBe(1)
			expect(CreatureService.modelAt(owner, "1") ~= nil).toBe(true)
			expect(string.find(owner.plot.geometry.sign.Text, "★", 1, true) ~= nil).toBe(true)
			Actors.removeBot(bot)
			DayNightService.forcePhase(nil)
		end)

		it("o treabă terminată se plătește o dată, apoi bonusul pentru toate", function()
			local bot, owner = botOwner(2, "HarnicBot")
			Quests.ensure(owner.profile, Daily.dayOf(os.time()), owner.userId) -- ziua în care rulează serverul
			for _, quest in owner.profile.quests.list do
				Quests.record(owner.profile, quest.kind, quest.goal)
			end
			local before = owner.profile.lei
			expect(NotebookService.claimQuest(owner, 1)).toBe(Notebook.quests.minReward)
			expect(NotebookService.claimQuest(owner, 1) == nil).toBe(true)
			expect(owner.profile.lei).toBe(before + Notebook.quests.minReward)
			expect(NotebookService.claimBonus(owner) == nil).toBe(true)
			NotebookService.claimQuest(owner, 2)
			NotebookService.claimQuest(owner, 3)
			expect(NotebookService.claimBonus(owner) ~= nil).toBe(true)
			Actors.removeBot(bot)
		end)
	end)

	describe("Schimburile", function()
		local function trader(index: number, name: string, id: string): (any, any, string)
			local bot, owner = botOwner(index, name)
			local record = Inventory.newRecord(owner.profile, bot.id, id, "Normal", nil)
			table.insert(owner.profile.cellar, record)
			owner.profile.lei = 500
			return bot, owner, record.uid
		end

		it("cerere, oferte, acceptare de ambele părți, numărătoare, apoi totul se mută", function()
			local botA, a, uidA = trader(3, "NegustorA", "CeapaTurbo")
			local botB, b, uidB = trader(4, "NegustorB", "Mamaligator")
			expect(TradeService.request(a, b)).toBe(true)
			expect(TradeService.respond(b, a, true)).toBe(true)
			expect(TradeService.isTrading(a) and TradeService.isTrading(b)).toBe(true)
			expect(TradeService.offer(a, { uidA }, 200)).toBe(true)
			expect(TradeService.offer(b, { uidB }, 0)).toBe(true)
			TradeService.accept(a)
			expect(TradeService.confirmAt(a) == nil).toBe(true) -- doar unul a acceptat
			TradeService.accept(b)
			expect(TradeService.confirmAt(a) ~= nil).toBe(true)
			-- un „Accept” repetat în numărătoare nu programează a doua execuție (leii s-ar muta de două ori)
			expect(TradeService.accept(b)).toBe(false)
			expect(TradeService.accept(a)).toBe(false)
			expect(Spec.waitFor(function()
				return not TradeService.isTrading(a)
			end, 6)).toBe(true)
			expect(Inventory.findCellar(a.profile, uidB) ~= nil).toBe(true)
			expect(Inventory.findCellar(b.profile, uidA) ~= nil).toBe(true)
			expect(Inventory.findCellar(a.profile, uidA) == nil).toBe(true)
			expect(a.profile.lei).toBe(300)
			expect(b.profile.lei).toBe(700)
			expect(a.profile.collection.Mamaligator == nil).toBe(true) -- schimbul nu umple Caietul
			Actors.removeBot(botA)
			Actors.removeBot(botB)
		end)

		it(
			"o ofertă schimbată în numărătoare oprește schimbul; o creatură vândută îl anulează",
			function()
				local botA, a, uidA = trader(5, "SiretA", "CeapaTurbo")
				local botB, b, uidB = trader(6, "SiretB", "Mamaligator")
				TradeService.request(a, b)
				TradeService.respond(b, a, true)
				TradeService.offer(a, { uidA }, 0)
				TradeService.offer(b, { uidB }, 0)
				TradeService.accept(a)
				TradeService.accept(b)
				TradeService.offer(b, {}, 0) -- trage oferta înapoi în ultima clipă
				expect(TradeService.confirmAt(a) == nil).toBe(true)
				task.wait(3.5)
				expect(TradeService.isTrading(a)).toBe(true)
				expect(Inventory.findCellar(a.profile, uidA) ~= nil).toBe(true)
				-- din nou, dar B își vinde creatura în timpul numărătorii
				TradeService.offer(b, { uidB }, 0)
				TradeService.accept(a)
				TradeService.accept(b)
				Inventory.remove(b.profile, uidB)
				expect(Spec.waitFor(function()
					return not TradeService.isTrading(a)
				end, 6)).toBe(true)
				expect(Inventory.findCellar(a.profile, uidA) ~= nil).toBe(true) -- nimic nu s-a mutat
				expect(Inventory.findCellar(b.profile, uidA) == nil).toBe(true)
				Actors.removeBot(botA)
				Actors.removeBot(botB)
			end
		)

		it("plecarea unei părți închide schimbul", function()
			local botA, a = trader(7, "PlecatA", "CeapaTurbo")
			local botB, b = trader(8, "PlecatB", "Mamaligator")
			TradeService.request(a, b)
			TradeService.respond(b, a, true)
			Actors.removeBot(botB)
			expect(TradeService.isTrading(a)).toBe(false)
			Actors.removeBot(botA)
		end)
	end)
end
