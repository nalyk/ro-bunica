--!strict
-- Ceasul satului: pornire forțată, un bot strânge, primește răsplata, oprire curată (nu rămâne nimic în lume).

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local happenings = ServerScriptService.Server:WaitForChild("Happenings")
	local PlotService = services.PlotService
	local Clock = services.VillageClockService

	local function botOwner(name: string, index: number): (any, any)
		local bot = Actors.createBot(name, PlotService.plots[index].geometry.spawnCFrame)
		local owner = PlotService.assignBot(PlotService.plots[index], bot)
		return bot, owner
	end

	local function teleport(bot: any, position: Vector3)
		(Actors.characterOf(bot) :: Model):PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))
	end

	describe("Ceasul satului", function()
		Clock.setEnabled(false)

		it(
			"Gâștele: botul prinde o gâscă, o duce la țarc și ia 30 de lei; la final nu rămâne nimic",
			function()
				local Gaste = (require :: any)(happenings.Gaste)
				local bot, owner = botOwner("Gascar", 6)
				expect(Clock.begin("Gaste", 60)).toBe(true)
				local ctx = Clock.active()
				local goose = Gaste.geese(ctx)[1]
				teleport(bot, goose.model:GetPivot().Position)
				expect(Spec.waitFor(function()
					return goose.carrier == owner
				end, 3)).toBe(true)
				local before = owner.profile.lei
				teleport(bot, ctx.data.pen)
				expect(Spec.waitFor(function()
					return goose.model:GetAttribute("Penned") == true
				end, 3)).toBe(true)
				expect(owner.profile.lei - before).toBe(Gaste.LEI)
				local folder = ctx.folder
				Clock.stop()
				expect(Spec.waitFor(function()
					return Clock.active() == nil and folder.Parent == nil
				end, 3)).toBe(true)
				-- podiumul: locul 1 = participare + 60
				expect(owner.profile.lei - before >= Gaste.LEI + 40 + 60).toBe(true)
				expect(Workspace:FindFirstChild("Happening_Gaste") == nil).toBe(true)
				Actors.removeBot(bot)
			end
		)

		it(
			"Cireșele: botul le strânge pe toate (5 lei bucata), iar întâmplarea se încheie singură",
			function()
				local Cirese = (require :: any)(happenings.Cirese)
				local bot, owner = botOwner("Culegator", 7)
				expect(Clock.begin("Cirese", 90)).toBe(true)
				local ctx = Clock.active()
				local before = owner.profile.lei
				for _, cherry in ctx.data.cherries do
					if cherry.Parent then
						teleport(bot, cherry.Position)
						Spec.waitFor(function()
							return cherry.Parent == nil
						end, 2)
					end
				end
				expect(Cirese.remaining(ctx)).toBe(0)
				expect(Spec.waitFor(function()
					return Clock.active() == nil
				end, 3)).toBe(true)
				expect(owner.profile.lei - before >= Cirese.COUNT * Cirese.LEI).toBe(true)
				expect(Workspace:FindFirstChild("Happening_Cirese") == nil).toBe(true)
				Actors.removeBot(bot)
			end
		)

		it("Negustorul: botul de lângă el cumpără o sămânță rară cu reducere", function()
			local Negustor = (require :: any)(happenings.Negustor)
			local bot, owner = botOwner("Cumparator", 6)
			owner.profile.lei = 10000000
			expect(Clock.begin("Negustor", 60)).toBe(true)
			local ctx = Clock.active()
			local offer = Negustor.offers(ctx)[1]
			expect(offer ~= nil and offer.price > 0).toBe(true)
			-- departe de negustor nu se poate
			Clock.act(owner, { buy = offer.seedId })
			expect(owner.profile.seeds[offer.seedId] or 0).toBe(0)
			teleport(bot, ctx.data.merchant:GetPivot().Position + Vector3.new(3, 0, 0))
			task.wait(0.2)
			local before = owner.profile.lei
			Clock.act(owner, { buy = offer.seedId })
			expect(owner.profile.seeds[offer.seedId]).toBe(1)
			expect(before - owner.profile.lei).toBe(offer.price)
			-- o singură sămânță de jucător
			Clock.act(owner, { buy = offer.seedId })
			expect(owner.profile.seeds[offer.seedId]).toBe(1)
			Clock.stop()
			Actors.removeBot(bot)
		end)

		it("Nunta: cine merge în hora cortegiului ia câte un leu pe secundă", function()
			local Nunta = (require :: any)(happenings.Nunta)
			local bot, owner = botOwner("Nuntas", 7)
			expect(Clock.begin("Nunta", 40)).toBe(true)
			local ctx = Clock.active()
			local before = owner.profile.lei
			local deadline = os.clock() + 5
			while os.clock() < deadline do
				teleport(bot, Nunta.center(ctx) + Vector3.new(2, 0, 0))
				task.wait(0.25)
			end
			expect(owner.profile.lei - before >= 3).toBe(true)
			expect(ctx.participants[owner]).toBe(true)
			Clock.stop()
			Actors.removeBot(bot)
		end)

		it("Ceața: Bunicile văd la jumătate cât ține, apoi revin; ceața ajunge la clienți", function()
			local GameState = require(game:GetService("ReplicatedStorage").Shared.GameState)
			local BunicaService = services.BunicaService
			expect(BunicaService.sight()).toBe(1)
			expect(Clock.begin("Ceata", 30)).toBe(true)
			expect(BunicaService.sight()).toBe(0.5)
			expect(GameState.get(GameState.Attributes.Fog)).toBe(1)
			Clock.stop()
			expect(Spec.waitFor(function()
				return Clock.active() == nil
			end, 3)).toBe(true)
			expect(BunicaService.sight()).toBe(1)
			expect(GameState.get(GameState.Attributes.Fog)).toBe(0)
		end)

		it("Lupii: două papuce gonesc lupul, iar apărătorul își ia partea din răsplată", function()
			local Lupi = (require :: any)(happenings.Lupi)
			local SlipperService = services.SlipperService
			local bot, owner = botOwner("Cioban", 6)
			expect(Clock.begin("Lupi", 90)).toBe(true)
			local ctx = Clock.active()
			expect(Spec.waitFor(function()
				return #Lupi.wolves(ctx) >= 1
			end, 3)).toBe(true)
			local wolf = Lupi.wolves(ctx)[1]
			local deadline = os.clock() + 12
			while wolf.state ~= "Fleeing" and wolf.state ~= "Gone" and os.clock() < deadline do
				local at = wolf.model:GetPivot().Position
				teleport(bot, at + Vector3.new(9, 0, 0))
				task.wait(0.1)
				SlipperService.throwAs(bot, wolf.model:GetPivot().Position, "Slipper")
				task.wait(0.7)
			end
			expect(wolf.state == "Fleeing" or wolf.state == "Gone").toBe(true)
			expect(ctx.data.hits[owner] >= 2).toBe(true)
			local before = owner.profile.lei
			Clock.stop()
			expect(Spec.waitFor(function()
				return Clock.active() == nil
			end, 3)).toBe(true)
			expect(owner.profile.lei > before).toBe(true)
			Actors.removeBot(bot)
		end)

		it("Muma Pădurii: papucii îi scad viața; cine o alungă ia o sămânță Epic", function()
			local Muma = (require :: any)(happenings.MumaPadurii)
			local SlipperService = services.SlipperService
			local bot, owner = botOwner("Vanator", 6)
			expect(Clock.begin("MumaPadurii", 120)).toBe(true)
			local ctx = Clock.active()
			expect(Muma.health(ctx)).toBe(Muma.HEALTH)
			ctx.data.health = 2 -- testul nu aruncă de 40 de ori
			local seedsBefore = 0
			for _, n in owner.profile.seeds do
				seedsBefore += n
			end
			local deadline = os.clock() + 15
			while Clock.active() ~= nil and os.clock() < deadline do
				local at = ctx.data.muma:GetPivot().Position
				teleport(bot, at + Vector3.new(10, 0, 0))
				task.wait(0.1)
				SlipperService.throwAs(bot, at + Vector3.new(0, 3, 0), "Slipper")
				task.wait(0.8)
			end
			expect(Clock.active() == nil).toBe(true)
			local seedsAfter = 0
			for _, n in owner.profile.seeds do
				seedsAfter += n
			end
			expect(seedsAfter).toBe(seedsBefore + 1)
			Actors.removeBot(bot)
		end)

		it(
			"Trenul: vine, oprește în gară, iar pe peron se cumpără o sămânță Legendară la jumătate",
			function()
				local Tren = (require :: any)(happenings.Tren)
				local bot, owner = botOwner("Calator2", 7)
				owner.profile.lei = 100000000
				expect(Clock.begin("Tren", 40)).toBe(true)
				local ctx = Clock.active()
				expect(Tren.state(ctx)).toBe("Arriving")
				expect(Spec.waitFor(function()
					return Tren.state(ctx) == "Stopped"
				end, Tren.ARRIVE + 3)).toBe(true)
				teleport(bot, ctx.data.platform)
				task.wait(0.2)
				local offer = ctx.data.offer
				expect(offer ~= nil).toBe(true)
				Clock.act(owner, { buy = offer.seedId })
				expect(owner.profile.seeds[offer.seedId]).toBe(1)
				Clock.stop()
				Actors.removeBot(bot)
			end
		)

		it("nu pornesc două întâmplări deodată", function()
			expect(Clock.begin("Gaste", 30)).toBe(true)
			expect(Clock.begin("Cirese", 30)).toBe(false)
			Clock.stop()
		end)
	end)
end
