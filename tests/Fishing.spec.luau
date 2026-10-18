local Fishing = require(Shared.Domain.Fishing)
local Fish = require(Shared.Config.Fish)
local Scatter = require(Shared.Domain.Scatter)

describe("Fishing", function()
	it("șansele însumează 1, pe orice vreme și anotimp", function()
		for _, weather in { "", "Rain", "GoldHarvest" } do
			for _, season in { "Primavara", "Vara", "Toamna", "Iarna" } do
				local total = 0
				for _, p in Fishing.odds(weather, season) do
					total += p
				end
				expect(math.abs(total - 1) < 1e-9).toBe(true)
			end
		end
	end)
	it("ploaia face peștii rari mai deși", function()
		local dry, rain = Fishing.odds("", "Vara"), Fishing.odds("Rain", "Vara")
		expect(rain.stiucaNinja > dry.stiucaNinja).toBe(true)
	end)
	it("tragerea la sorți dă doar pești din config, determinist pe rng", function()
		local a, b = Scatter.rng(4), Scatter.rng(4)
		for _ = 1, 50 do
			local x = Fishing.roll(a, "", "Vara")
			expect(Fish.byId[x] ~= nil).toBe(true)
			expect(Fishing.roll(b, "", "Vara")).toBe(x)
		end
	end)
	it("bara de tensiune: ții = crește, lași = scade; peste maxim se rupe firul", function()
		local state = Fishing.newReel()
		Fishing.reel(state, true, 0.5, 0)
		expect(state.tension > 0).toBe(true)
		local held = state.tension
		Fishing.reel(state, false, 0.5, 0)
		expect(state.tension < held).toBe(true)
		local snap = Fishing.newReel()
		for _ = 1, 40 do
			Fishing.reel(snap, true, 0.1, 0.5)
		end
		expect(snap.state).toBe("Snapped")
	end)
	it("în zona bună, progresul crește până prinzi peștele", function()
		local state = Fishing.newReel()
		state.tension = 0.55
		for _ = 1, 200 do
			if state.state ~= "Reeling" then
				break
			end
			-- ține tensiunea în mijloc: apasă când scade sub 0,5
			Fishing.reel(state, state.tension < 0.5, 0.05, 0)
		end
		expect(state.state).toBe("Caught")
	end)
end)
