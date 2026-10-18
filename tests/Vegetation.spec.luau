local Vegetation = require(Shared.Domain.Vegetation)
local VillageLayout = require(Shared.Domain.VillageLayout)
local Village = require(Shared.Config.Village)

describe("Vegetation", function()
	local layout = VillageLayout.build()
	local plan = Vegetation.plan(layout, Village.variantSeed)
	local counts = Vegetation.count(plan)

	it("același seed dă același plan", function()
		local again = Vegetation.plan(layout, Village.variantSeed)
		expect(#again).toBe(#plan)
		expect(again[17].x).toBe(plan[17].x)
		expect(again[#again].key).toBe(plan[#plan].key)
	end)

	it(
		"satul e plin, dar în limite: aleea, plopii, livezile, pâlcurile, codrul, stuful, florile",
		function()
			local trees = 0
			for key, n in counts do
				if Vegetation.TREES[key] then
					trees += n
				end
			end
			print(string.format("vegetație: %d bucăți, %d copaci", #plan, trees))
			for key, n in counts do
				print("  " .. key .. " " .. n)
			end
			expect(counts["world.Salcam"] >= 30).toBe(true)
			expect(counts["world.Plop"] >= 30).toBe(true)
			expect(counts["world.Stejar"] >= 30).toBe(true)
			expect(counts["world.Stuf"] >= 15).toBe(true)
			expect(counts["world.Flori"] >= 40).toBe(true)
			expect(counts["world.Tufa"] >= 20).toBe(true)
			expect(trees >= 200 and trees <= 520).toBe(true)
			expect(#plan <= 1100).toBe(true)
		end
	)

	it("nimic pe drumuri, în ogrăzi, în locuri sau în apa iazului", function()
		local pond = layout.sites.iaz.Position
		for _, item in plan do
			local p = Vector3.new(item.x, 0, item.z)
			expect(VillageLayout.distanceToRoad(layout, p) > Village.roadWidth / 2).toBe(true)
			for _, plot in layout.plots do
				expect(VillageLayout.contains(plot, p, 2)).toBe(false)
			end
			expect((Vector3.new(pond.X, 0, pond.Z) - p).Magnitude > 32).toBe(true)
			if item.key ~= "world.Stuf" then
				expect(Vegetation.free(layout, p, 0)).toBe(true)
			end
		end
	end)

	it("copacii nu cresc unul în altul", function()
		local trunks = {}
		for _, item in plan do
			if Vegetation.TREES[item.key] then
				local p = Vector3.new(item.x, 0, item.z)
				for _, q in trunks do
					expect((p - q).Magnitude >= 8).toBe(true)
				end
				table.insert(trunks, p)
			end
		end
	end)
end)
