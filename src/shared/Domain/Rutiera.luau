--!strict
-- Rutiera satului: un traseu în opt pe toate drumurile (drumul mare spre est până la ulicioară, pe lângă centru,
-- ulița de deal spre est, conectorul de est, drumul mare înapoi spre ulicioară, iar prin centru, ulița de deal
-- spre vest, conectorul de vest). Oprire la centru și la poarta fiecărei ogrăzi. Orarul: un circuit în
-- `period` secunde, cu `dwell` secunde de oprire la fiecare stație.

local Config = script.Parent.Parent.Config
local Village = require(Config.Village)
local VillageLayout = require(script.Parent.VillageLayout)

export type Circuit = { points: { Vector3 }, cumulative: { number }, total: number }
export type Stop = { name: string, t: number }
type Segment = { from: number, to: number, t0: number, t1: number }
export type Schedule = { period: number, segments: { Segment }, arrivals: { [string]: number } }

local Rutiera = {}

local function sample(f: (number) -> Vector3, a: number, b: number, n: number, out: { Vector3 })
	for i = 0, n do
		local p = f(a + (b - a) * i / n)
		local last = out[#out]
		if not last or (last - p).Magnitude > 0.01 then
			table.insert(out, p)
		end
	end
end

local function add(out: { Vector3 }, p: Vector3)
	local last = out[#out]
	if not last or (last - p).Magnitude > 0.01 then
		table.insert(out, p)
	end
end

function Rutiera.circuit(_layout: VillageLayout.Layout): Circuit
	local ext = Village.extent
	local hub = Village.hub
	local points: { Vector3 } = {}
	-- prin centru, pe lângă hora și fântână (ocolul de est, la 18 studs): nu calcă dansatorii
	local function aroundHub()
		add(points, hub + Vector3.new(14, 0, -12))
		add(points, hub + Vector3.new(18, 0, 0))
		add(points, hub + Vector3.new(14, 0, 12))
	end
	sample(VillageLayout.lower, -ext, 0, 30, points)
	aroundHub()
	sample(VillageLayout.upper, 0, ext, 30, points)
	sample(VillageLayout.lower, ext, 0, 30, points)
	aroundHub()
	sample(VillageLayout.upper, 0, -ext, 30, points)
	add(points, VillageLayout.lower(-ext))
	local cumulative, total = { 0 }, 0
	for i = 2, #points do
		total += (points[i] - points[i - 1]).Magnitude
		table.insert(cumulative, total)
	end
	return { points = points, cumulative = cumulative, total = total }
end

-- Poziția și direcția la fracțiunea t ∈ [0, 1] din circuit
function Rutiera.at(circuit: Circuit, t: number): (Vector3, Vector3)
	local distance = (t % 1) * circuit.total
	local lo, hi = 1, #circuit.cumulative
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if circuit.cumulative[mid] <= distance then
			lo = mid
		else
			hi = mid
		end
	end
	local a, b = circuit.points[lo], circuit.points[hi]
	local span = circuit.cumulative[hi] - circuit.cumulative[lo]
	local f = if span > 0 then (distance - circuit.cumulative[lo]) / span else 0
	return a:Lerp(b, f), (b - a).Unit
end

-- Fracțiunea t a celui mai apropiat punct de circuit (la egalitate, primul)
local function project(circuit: Circuit, p: Vector3): (number, number)
	local bestT, bestD = 0, math.huge
	local flat = Vector3.new(p.X, 0, p.Z)
	for i = 1, #circuit.points - 1 do
		local a, b = circuit.points[i], circuit.points[i + 1]
		local fa, fb = Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z)
		local ab = fb - fa
		local len2 = ab:Dot(ab)
		local f = if len2 > 0 then math.clamp((flat - fa):Dot(ab) / len2, 0, 1) else 0
		local d = (flat - (fa + ab * f)).Magnitude
		if d < bestD - 1e-6 then
			bestD = d
			bestT = (circuit.cumulative[i] + f * math.sqrt(len2)) / circuit.total
		end
	end
	return bestT, bestD
end

function Rutiera.stops(layout: VillageLayout.Layout, circuit: Circuit): { Stop }
	local list: { Stop } = {}
	table.insert(list, { name = "centru", t = (project(circuit, Village.hub)) })
	for index, plot in layout.plots do
		table.insert(list, { name = "plot" .. index, t = (project(circuit, plot.gate)) })
	end
	table.sort(list, function(a, b)
		return a.t < b.t
	end)
	return list
end

-- Prima oprire de după t (circuitul se reia de la capăt)
function Rutiera.nextStop(stops: { Stop }, t: number): Stop
	for _, stop in stops do
		if stop.t >= t % 1 then
			return stop
		end
	end
	return stops[1]
end

function Rutiera.schedule(stops: { Stop }, period: number, dwell: number): Schedule
	local moving = period - dwell * #stops
	local segments: { Segment } = {}
	local arrivals: { [string]: number } = {}
	local clock, t = 0, 0
	for _, stop in stops do
		local duration = (stop.t - t) * moving
		table.insert(segments, { from = clock, to = clock + duration, t0 = t, t1 = stop.t })
		clock += duration
		arrivals[stop.name] = clock
		table.insert(segments, { from = clock, to = clock + dwell, t0 = stop.t, t1 = stop.t })
		clock += dwell
		t = stop.t
	end
	table.insert(segments, { from = clock, to = period, t0 = t, t1 = 1 })
	return { period = period, segments = segments, arrivals = arrivals }
end

-- Fracțiunea din circuit la secunda `seconds` (periodic)
function Rutiera.progress(schedule: Schedule, seconds: number): number
	local s = seconds % schedule.period
	for _, segment in schedule.segments do
		if s <= segment.to then
			local span = segment.to - segment.from
			local f = if span > 0 then (s - segment.from) / span else 0
			return (segment.t0 + (segment.t1 - segment.t0) * f) % 1
		end
	end
	return 0
end

-- Secunda (din circuit) la care rutiera ajunge în stația dată
function Rutiera.arrival(schedule: Schedule, name: string): number
	return schedule.arrivals[name] or 0
end

return Rutiera
