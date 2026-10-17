local Family = require(Shared.Domain.Family)
local Ritual = require(Shared.Domain.Ritual)

local function friendsFrom(pairs)
	local set = {}
	for _, p in pairs do
		set[p[1] .. ":" .. p[2]] = true
		set[p[2] .. ":" .. p[1]] = true
	end
	return function(a, b)
		return set[a .. ":" .. b] == true
	end
end

describe("Family.bonded și canSwitch", function()
	it("familia cere ambele moduri pe Family; un Rival îi face rivali", function()
		expect(Family.bonded("Family", "Family")).toBe(true)
		expect(Family.bonded(nil, "Family")).toBe(true)
		expect(Family.bonded("Rival", "Family")).toBe(false)
		expect(Family.bonded("Family", "Rival")).toBe(false)
	end)
	it("modul se schimbă doar ziua, cu pauză între schimbări", function()
		expect(Family.canSwitch("Day", nil, 100, 10)).toBe(true)
		expect(Family.canSwitch("Night", nil, 100, 10)).toBe(false)
		expect(Family.canSwitch("Day", 95, 100, 10)).toBe(false)
		expect(Family.canSwitch("Day", 90, 100, 10)).toBe(true)
	end)
end)

describe("Family.group", function()
	it("prietenii devin o familie, singurii rămân fără", function()
		local result = Family.group({ 1, 2, 3 }, friendsFrom({ { 1, 2 } }), 4)
		expect(result[1]).toBe(1)
		expect(result[2]).toBe(1)
		expect(result[3]).toBeNil()
	end)
	it("prietenul prietenului intră în aceeași familie", function()
		local result = Family.group({ 1, 2, 3 }, friendsFrom({ { 1, 2 }, { 2, 3 } }), 4)
		expect(result[3]).toBe(1)
	end)
	it("împarte familiile prea mari", function()
		local all = {}
		for a = 1, 6 do
			for b = a + 1, 6 do
				table.insert(all, { a, b })
			end
		end
		local result = Family.group({ 1, 2, 3, 4, 5, 6 }, friendsFrom(all), 4)
		expect(result[1]).toBe(1)
		expect(result[4]).toBe(1)
		expect(result[5]).toBe(5)
		expect(result[6]).toBe(5)
	end)
end)

describe("Family.choosePlot", function()
	it("fără prieteni alege prima liberă", function()
		expect(Family.choosePlot({ Vector3.new(0, 0, 0), Vector3.new(90, 0, 0) }, {})).toBe(1)
	end)
	it("alege ograda cea mai apropiată de un prieten", function()
		local free = { Vector3.new(-135, 0, 47), Vector3.new(135, 0, 47) }
		expect(Family.choosePlot(free, { Vector3.new(45, 0, 47) })).toBe(2)
	end)
	it("nicio ogradă liberă", function()
		expect(Family.choosePlot({}, {})).toBeNil()
	end)
end)

describe("Ritual", function()
	local config = { center = Vector3.new(0, 0, 0), radius = 10, minDancers = 3, holdSeconds = 4 }
	local function dancers(n, offset)
		local list = {}
		for i = 1, n do
			table.insert(list, { id = i, position = Vector3.new(offset or 5, 0, 0) })
		end
		return list
	end
	it("se împlinește după timpul cerut", function()
		local state = {}
		expect((Ritual.update(state, dancers(3), 0, config))).toBe(false)
		expect((Ritual.update(state, dancers(3), 3.9, config))).toBe(false)
		local done, ids = Ritual.update(state, dancers(3), 4, config)
		expect(done).toBe(true)
		expect(#ids).toBe(3)
	end)
	it("se resetează când scad dansatorii", function()
		local state = {}
		Ritual.update(state, dancers(3), 0, config)
		Ritual.update(state, dancers(2), 2, config)
		expect((Ritual.update(state, dancers(3), 4, config))).toBe(false)
	end)
	it("dansatorii din afara cercului nu contează", function()
		local state = {}
		Ritual.update(state, dancers(3, 50), 0, config)
		expect((Ritual.update(state, dancers(3, 50), 10, config))).toBe(false)
	end)
end)
