local Compass = require(Shared.Domain.Compass)
local MapView = require(Shared.Domain.MapView)
local Waypoint = require(Shared.Domain.Waypoint)

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

describe("Compass", function()
	it("direcția: nordul e −Z, estul +X (în grade, 0–360)", function()
		expect(near(Compass.heading(Vector3.new(0, 0, -1)), 0)).toBe(true)
		expect(near(Compass.heading(Vector3.new(1, 0, 0)), 90)).toBe(true)
		expect(near(Compass.heading(Vector3.new(0, 0, 1)), 180)).toBe(true)
		expect(near(Compass.heading(Vector3.new(-1, 0, 0)), 270)).toBe(true)
		expect(near(Compass.bearing(Vector3.new(5, 3, 5), Vector3.new(15, 0, 5)), 90)).toBe(true)
	end)

	it("diferența de unghi trece corect peste nord", function()
		expect(near(Compass.delta(10, 350), 20)).toBe(true)
		expect(near(Compass.delta(350, 10), -20)).toBe(true)
		expect(near(Compass.delta(180, 0), 180)).toBe(true)
	end)

	it(
		"plasarea pe bandă: în câmp după unghi; în afara lui doar semnele fixate, lipite de margine",
		function()
			local x, edge = Compass.place(45, 90, 300)
			expect(near(x :: number, 75)).toBe(true)
			expect(edge).toBe(false)
			expect(Compass.place(120, 90, 300)).toBe(nil)
			local pinned, atEdge = Compass.place(-150, 90, 300, true)
			expect(near(pinned :: number, -150)).toBe(true)
			expect(atEdge).toBe(true)
		end
	)

	it("punctele cardinale vizibile, cu poziția lor", function()
		local marks = Compass.cardinals(0, 60)
		local ids = {}
		for _, mark in marks do
			ids[mark.id] = mark.delta
		end
		expect(ids.N).toBe(0)
		expect(ids.NE).toBe(45)
		expect(ids.NV).toBe(-45)
		expect(ids.E).toBe(nil)
	end)

	it("semnele apropiate nu se suprapun: cele importante rămân pe rândul de sus", function()
		local rows = Compass.rows({
			{ id = "casa", x = 0, priority = 1 },
			{ id = "prieten", x = 10, priority = 3 },
			{ id = "hot", x = 5, priority = 0 },
			{ id = "rutiera", x = 80, priority = 2 },
		}, 24)
		expect(rows.hot).toBe(0)
		expect(rows.casa).toBe(1)
		expect(rows.prieten).toBe(2)
		expect(rows.rutiera).toBe(0)
	end)

	it("distanța în metri (1 stud ≈ 0,28 m), rotunjită pentru citit dintr-o privire", function()
		expect(Compass.metres(36)).toBe(10)
		expect(Compass.metres(100)).toBe(30)
		expect(Compass.metres(1000)).toBe(280)
		expect(Compass.metres(5)).toBe(0)
	end)
end)

describe("MapView", function()
	local bounds = { minX = -100, maxX = 100, minZ = -50, maxZ = 50 }

	it("satul încape întreg, centrat, cu proporțiile păstrate", function()
		local size = Vector2.new(400, 400)
		local a = MapView.toMap(bounds, size, Vector3.new(-100, 0, -50))
		local b = MapView.toMap(bounds, size, Vector3.new(100, 0, 50))
		expect(near(a.X, 0) and near(b.X, 400)).toBe(true)
		expect(near(a.Y, 100) and near(b.Y, 300)).toBe(true)
	end)

	it("dus și întors: punctul atins pe hartă e locul din sat", function()
		local size = Vector2.new(640, 360)
		local p = Vector3.new(37, 0, -12)
		local back = MapView.toWorld(bounds, size, MapView.toMap(bounds, size, p))
		expect(near(back.X, 37) and near(back.Z, -12)).toBe(true)
	end)

	it("marginile: tot ce contează din sat, plus o margine", function()
		local b = MapView.boundsOf({ Vector3.new(-10, 0, 5), Vector3.new(30, 0, -20) }, 5)
		expect(b.minX == -15 and b.maxX == 35 and b.minZ == -25 and b.maxZ == 10).toBe(true)
	end)
end)

describe("Waypoint", function()
	it("sosirea: pe orizontală, în raza dată", function()
		expect(Waypoint.arrived(Vector3.new(0, 10, 0), Vector3.new(8, 0, 0), 12)).toBe(true)
		expect(Waypoint.arrived(Vector3.new(0, 0, 0), Vector3.new(20, 0, 0), 12)).toBe(false)
	end)

	it("poteca: puncte la pas egal pe drum, până la lungimea cerută", function()
		local points =
			Waypoint.trail({ Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), Vector3.new(10, 0, 10) }, 4, 14)
		expect(#points).toBe(4) -- 0, 4, 8, 12
		expect(near(points[3].X, 8) and near(points[3].Z, 0)).toBe(true)
		expect(near(points[4].X, 10) and near(points[4].Z, 2)).toBe(true)
	end)

	it("drum gol sau de un singur punct: fără potecă", function()
		expect(#Waypoint.trail({}, 4, 50)).toBe(0)
		expect(#Waypoint.trail({ Vector3.new(1, 0, 1) }, 4, 50)).toBe(0)
	end)
end)
