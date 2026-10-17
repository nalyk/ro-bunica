local VillageLayout = require(Shared.Domain.VillageLayout)
local World = require(Shared.Config.World)

local function corners(plot: any): { Vector3 }
	local list = {}
	for _, d in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		local local_ = Vector3.new(d[1] * World.plotSize.X / 2, 0, d[2] * World.plotSize.Z / 2)
		table.insert(list, plot.cframe:PointToWorldSpace(local_))
	end
	return list
end

-- dreptunghiuri orientate (SAT), cu o margine de siguranță
local function overlaps(a: any, b: any, pad: number): boolean
	local A, B = corners(a), corners(b)
	for _, poly in { A, B } do
		for i = 1, 4 do
			local p, q = poly[i], poly[i % 4 + 1]
			local axis = Vector3.new(-(q.Z - p.Z), 0, q.X - p.X).Unit
			local minA, maxA, minB, maxB = math.huge, -math.huge, math.huge, -math.huge
			for _, c in A do
				local d = c:Dot(axis)
				minA, maxA = math.min(minA, d), math.max(maxA, d)
			end
			for _, c in B do
				local d = c:Dot(axis)
				minB, maxB = math.min(minB, d), math.max(maxB, d)
			end
			if maxA + pad < minB or maxB + pad < minA then
				return false
			end
		end
	end
	return true
end

describe("VillageLayout", function()
	local layout = VillageLayout.build()

	it("are 8 ogrăzi care nu se suprapun", function()
		expect(#layout.plots).toBe(8)
		for i = 1, 8 do
			for j = i + 1, 8 do
				expect(overlaps(layout.plots[i], layout.plots[j], 6)).toBe(false)
			end
		end
	end)

	it("e echitabil la raiduri: CV ≤ 0,10 și max/min ≤ 1,25 pe graful drumurilor", function()
		local f = VillageLayout.fairness(layout)
		expect(f.exposureCV <= 0.10).toBe(true)
		expect(f.exposureMaxMin <= 1.25).toBe(true)
	end)

	it("fiecare poartă e lângă un drum și cu fața spre el", function()
		for _, plot in layout.plots do
			expect(VillageLayout.distanceToRoad(layout, plot.gate) <= 20).toBe(true)
			local toGate = (plot.gate - plot.cframe.Position).Unit
			expect(plot.cframe.LookVector:Dot(toGate) > 0.95).toBe(true)
		end
	end)

	it("locurile satului sunt în afara ogrăzilor și departe de pârâu", function()
		for name, site in layout.sites do
			for _, plot in layout.plots do
				expect(VillageLayout.contains(plot, site.Position, 14)).toBe(false)
			end
			if name ~= "centru" then
				expect(VillageLayout.distanceToRoad(layout, site.Position) >= 14).toBe(true)
			end
			for other, o in layout.sites do
				if other ~= name then
					expect((Vector3.new(o.X, 0, o.Z) - Vector3.new(site.X, 0, site.Z)).Magnitude >= 30).toBe(
						true
					)
				end
			end
			expect(VillageLayout.distanceToRiver(layout, site.Position) >= 20 or name == "iaz").toBe(true)
		end
		for _, key in VillageLayout.SITE_KEYS do
			expect(layout.sites[key] ~= nil).toBe(true)
		end
	end)

	it("niciun drum sau potecă nu trece prin vreo ogradă", function()
		local all = table.clone(layout.roads)
		for _, path in layout.shortcuts do
			table.insert(all, path)
		end
		for _, road in all do
			for k = 1, #road.points - 1 do
				local a, b = road.points[k], road.points[k + 1]
				local n = math.max(1, math.ceil((b - a).Magnitude / 2))
				for step = 0, n do
					local p = a:Lerp(b, step / n)
					for _, plot in layout.plots do
						local l = plot.cframe:PointToObjectSpace(p)
						local inside = math.abs(l.X) <= World.plotSize.X / 2 + road.width / 2
							and math.abs(l.Z) <= World.plotSize.Z / 2 + road.width / 2
						if inside then
							error(string.format("%s trece prin ograda %d", road.name, plot.index))
						end
					end
				end
			end
		end
	end)

	it("e determinist", function()
		local again = VillageLayout.build()
		for i = 1, 8 do
			expect((again.plots[i].cframe.Position - layout.plots[i].cframe.Position).Magnitude < 1e-6).toBe(
				true
			)
		end
	end)
end)

describe("VillageLayout.variantFor", function()
	it("e determinist și dă 8 ogrăzi cu aspect diferit (poarta, decorul)", function()
		local seen = {}
		for index = 1, 8 do
			local a = VillageLayout.variantFor(index, 7)
			local b = VillageLayout.variantFor(index, 7)
			expect(a.gateColor == b.gateColor and a.treeSet == b.treeSet and a.mirrored == b.mirrored).toBe(
				true
			)
			local key = string.format("%s|%d|%s", tostring(a.gateColor), a.treeSet, tostring(a.mirrored))
			expect(seen[key]).toBeNil()
			seen[key] = true
		end
	end)
	it("vecinii de pe același drum nu au aceeași poartă", function()
		local layout = VillageLayout.build()
		for i = 1, 7 do
			local p, q = layout.plots[i], layout.plots[i + 1]
			if p.lane == q.lane then
				expect(
					VillageLayout.variantFor(i, 7).gateColor ~= VillageLayout.variantFor(i + 1, 7).gateColor
				).toBe(true)
			end
		end
	end)
end)
