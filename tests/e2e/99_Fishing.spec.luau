--!strict
-- Pescuitul la iaz: departe nu arunci; tragerea bună (refăcută pe server cu aceleași smucituri) prinde; vânzarea.

local ServerScriptService = game:GetService("ServerScriptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Fish = require(Shared.Config.Fish)
local Fishing = require(Shared.Domain.Fishing)
local VillageLayout = require(Shared.Domain.VillageLayout)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local FishingService = services.FishingService
	local pond = VillageLayout.build().sites.iaz.Position

	describe("Pescuitul", function()
		it("departe de iaz nu arunci; lângă iaz, o tragere bună prinde ceva; peștele se vinde", function()
			local actor = Actors.createBot("Pescar", PlotService.plots[6].geometry.spawnCFrame)
			local owner = PlotService.assignBot(PlotService.plots[6], actor)
			expect(FishingService.cast(owner)).toBe(false);
			(Actors.characterOf(actor) :: Model):PivotTo(CFrame.new(pond + Vector3.new(0, 4, 36)))
			task.wait(0.2)
			expect(FishingService.cast(owner)).toBe(true)
			expect(FishingService.cast(owner)).toBe(false) -- o singură undiță odată
			local seed = FishingService.biteNow(owner) :: number
			-- tragerea „perfectă”: ține când tensiunea scade sub mijloc
			local reel = Fishing.newReel()
			local pulls = Fishing.pulls(seed, Fish.maxSteps)
			local inputs = {}
			for step = 1, Fish.maxSteps do
				local hold = reel.tension < 0.5
				inputs[step] = hold
				Fishing.reel(reel, hold, Fish.reelStep, pulls[step])
				if reel.state ~= "Reeling" then
					break
				end
			end
			expect(reel.state).toBe("Caught")
			task.wait(#inputs * Fish.reelStep * 0.6) -- nu mai repede decât e fizic posibil
			local seedsBefore = 0
			for _, n in owner.profile.seeds do
				seedsBefore += n
			end
			local caught = FishingService.reel(owner, inputs)
			expect(caught ~= nil).toBe(true)
			local fish = Fish.byId[caught :: string]
			if fish.egg then
				local seedsAfter = 0
				for _, n in owner.profile.seeds do
					seedsAfter += n
				end
				expect(seedsAfter).toBe(seedsBefore + 1)
			else
				expect(owner.profile.fish[caught :: string]).toBe(1)
				local before = owner.profile.lei
				expect(FishingService.sell(owner, caught :: string, 5)).toBe(fish.sell)
				expect(owner.profile.lei - before).toBe(fish.sell)
				expect(owner.profile.fish[caught :: string]).toBe(0)
			end
			Actors.removeBot(actor)
		end)

		it("vânzarea cu un număr NaN (trimis de un client stricat) nu strică leii", function()
			local actor = Actors.createBot("NaN", PlotService.plots[7].geometry.spawnCFrame)
			local owner = PlotService.assignBot(PlotService.plots[7], actor)
			local before = owner.profile.lei
			local nan = 0 / 0
			expect(FishingService.sell(owner, "crapRacheta", nan)).toBe(0)
			services.EconomyService.addLei(owner, nan)
			expect(owner.profile.lei == owner.profile.lei).toBe(true) -- NaN ~= NaN
			expect(owner.profile.lei).toBe(before)
			Actors.removeBot(actor)
		end)

		it("o tragere prea rapidă (trimisă imediat) nu e crezută", function()
			local actor = Actors.createBot("Grabit", PlotService.plots[7].geometry.spawnCFrame)
			local owner = PlotService.assignBot(PlotService.plots[7], actor);
			(Actors.characterOf(actor) :: Model):PivotTo(CFrame.new(pond + Vector3.new(4, 4, 36)))
			task.wait(0.2)
			expect(FishingService.cast(owner)).toBe(true)
			FishingService.biteNow(owner)
			local inputs = table.create(60, false)
			expect(FishingService.reel(owner, inputs)).toBe(nil)
			Actors.removeBot(actor)
		end)
	end)
end
