local Rutiera = require(Shared.Domain.Rutiera)
local VillageLayout = require(Shared.Domain.VillageLayout)
local Village = require(Shared.Config.Village)

describe("Rutiera", function()
	local layout = VillageLayout.build()
	local circuit = Rutiera.circuit(layout)

	it("circuitul e închis și trece pe lângă centru, ocolind hora și fântâna", function()
		local first = circuit.points[1]
		local last = circuit.points[#circuit.points]
		expect((first - last).Magnitude < 1).toBe(true)
		local Hora = require(Shared.Config.Hora)
		local best = math.huge
		for i = 0, 4000 do
			local p = Rutiera.at(circuit, i / 4000)
			best = math.min(
				best,
				(Vector3.new(p.X, 0, p.Z) - Vector3.new(Village.hub.X, 0, Village.hub.Z)).Magnitude
			)
		end
		expect(best > Hora.radius + 4).toBe(true)
		expect(best < 30).toBe(true)
	end)

	it("are o oprire la centru și câte una la fiecare ogradă, aproape de poartă", function()
		local stops = Rutiera.stops(layout, circuit)
		expect(#stops).toBe(9)
		local names = {}
		for _, stop in stops do
			names[stop.name] = stop
		end
		expect(names.centru ~= nil).toBe(true)
		for index, plot in layout.plots do
			local stop = names["plot" .. index]
			expect(stop ~= nil).toBe(true)
			local p = Rutiera.at(circuit, stop.t)
			expect((Vector3.new(p.X, 0, p.Z) - Vector3.new(plot.gate.X, 0, plot.gate.Z)).Magnitude < 22).toBe(
				true
			)
		end
		for i = 2, #stops do
			expect(stops[i].t >= stops[i - 1].t).toBe(true)
		end
	end)

	it("următoarea oprire se ia în ordine și trece peste capătul circuitului", function()
		local stops = Rutiera.stops(layout, circuit)
		local last = stops[#stops]
		expect(Rutiera.nextStop(stops, last.t + 0.001).name).toBe(stops[1].name)
		expect(Rutiera.nextStop(stops, stops[1].t - 0.001).name).toBe(stops[1].name)
	end)

	it("orarul: 150 s pe circuit, cu oprire la fiecare stație; poziția e continuă", function()
		local stops = Rutiera.stops(layout, circuit)
		local schedule = Rutiera.schedule(stops, 150, 4)
		expect(Rutiera.progress(schedule, 0)).toBe(0)
		expect(math.abs(Rutiera.progress(schedule, 150) - 0) < 1e-6).toBe(true)
		local previous = Rutiera.progress(schedule, 0)
		for s = 0.5, 149.5, 0.5 do
			local t = Rutiera.progress(schedule, s)
			expect(t >= previous - 1e-9).toBe(true)
			previous = t
		end
		-- în oprire, progresul stă pe loc
		local stop = stops[2]
		local arrive = Rutiera.arrival(schedule, stop.name)
		expect(math.abs(Rutiera.progress(schedule, arrive + 1) - stop.t) < 1e-6).toBe(true)
		expect(math.abs(Rutiera.progress(schedule, arrive + 3.9) - stop.t) < 1e-6).toBe(true)
	end)
end)
