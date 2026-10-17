--!strict
-- Geometria satului de vale (Config/Village), pură: drumurile, ogrăzile, pârâul, locurile și echitatea
-- raidurilor măsurată pe graful drumurilor (Dijkstra de la poarta fiecărei ogrăzi).

local Config = script.Parent.Parent.Config
local Village = require(Config.Village)
local World = require(Config.World)

export type Road = { name: string, points: { Vector3 }, width: number }
export type PlotSpot = {
	index: number,
	cframe: CFrame,
	gate: Vector3,
	lane: string, -- "low" | "up"
	variant: number,
	mirrored: boolean,
}
export type Layout = {
	roads: { Road },
	plots: { PlotSpot },
	hub: CFrame,
	river: { Vector3 },
	bridges: { CFrame },
	shortcuts: { Road },
	sites: { [string]: CFrame },
}

local VillageLayout = {}

VillageLayout.SITE_KEYS = {
	"centru",
	"magazin",
	"statie",
	"discoteca",
	"terenScoala",
	"iaz",
	"livada",
	"lanPorumb",
	"via",
	"stana",
	"moara",
	"biserica",
	"codru",
	"gara",
	"bazar",
	"bucatarie",
	"claie",
}

function VillageLayout.lower(x: number): Vector3
	local c = Village.low
	return Vector3.new(x, 0, c.a * math.sin(x / c.p) - c.q * x * x)
end

function VillageLayout.upper(x: number): Vector3
	local c = Village.up
	return Vector3.new(x * c.scale + c.shift, 0, c.base + c.a * math.sin(x / c.p + c.phase) - c.q * x * x)
end

local function sample(f: (number) -> Vector3, from: number, to: number, count: number): { Vector3 }
	local list = {}
	for i = 0, count do
		table.insert(list, f(from + (to - from) * i / count))
	end
	return list
end

-- Poarta pe normala drumului (spre nord, unde sunt ogrăzile) și o abatere mică, ca în satele reale
local function spot(f: (number) -> Vector3, x: number): (Vector3, Vector3)
	local a, b = f(x - 2), f(x + 2)
	local t = (b - a).Unit
	local normal = Vector3.new(-t.Z, 0, t.X) -- spre +Z (nord) pentru drumuri de la vest la est
	local p = f(x)
	local gate = p + normal * Village.gateOffset
	local jitter = math.rad(5 * math.sin(x * 0.37))
	local toRoad = -normal
	local dir = Vector3.new(
		toRoad.X * math.cos(jitter) - toRoad.Z * math.sin(jitter),
		0,
		toRoad.X * math.sin(jitter) + toRoad.Z * math.cos(jitter)
	)
	return gate, dir
end

function VillageLayout.build(): Layout
	local extent = Village.extent
	local lowRoad = sample(VillageLayout.lower, -extent, extent, 58)
	local upRoad = sample(VillageLayout.upper, -extent, extent, 58)
	local hub = Village.hub
	local roads: { Road } = {
		{ name = "drumulMare", points = lowRoad, width = Village.roadWidth },
		{ name = "ulitaDeDeal", points = upRoad, width = Village.laneWidth },
		{
			name = "capatVest",
			points = { VillageLayout.lower(-extent), VillageLayout.upper(-extent) },
			width = Village.laneWidth,
		},
		{
			name = "capatEst",
			points = { VillageLayout.lower(extent), VillageLayout.upper(extent) },
			width = Village.laneWidth,
		},
		{
			name = "ulicioaraCentrului",
			points = { VillageLayout.lower(0), hub, VillageLayout.upper(0) },
			width = Village.laneWidth,
		},
	}
	local shortcuts: { Road } = {}
	for i, x in Village.shortcuts do
		table.insert(shortcuts, {
			name = "poteca" .. i,
			points = { VillageLayout.lower(x), VillageLayout.upper(x) },
			width = 6,
		})
	end
	local plots: { PlotSpot } = {}
	local function add(f: (number) -> Vector3, x: number, lane: string)
		local gate, dir = spot(f, x)
		local center = gate - dir * (World.plotSize.Z / 2)
		local index = #plots + 1
		table.insert(plots, {
			index = index,
			cframe = CFrame.lookAt(center, center + dir),
			gate = gate,
			lane = lane,
			variant = (index - 1) % 4 + 1,
			mirrored = index % 2 == 0,
		})
	end
	for _, x in Village.plotsLow do
		add(VillageLayout.lower, x, "low")
	end
	for _, x in Village.plotsUp do
		add(VillageLayout.upper, x, "up")
	end
	local river = {}
	for _, p in sample(VillageLayout.lower, -extent - 60, extent + 60, 70) do
		table.insert(river, p - Vector3.new(0, 0, Village.riverOffset))
	end
	local bridges = {}
	for _, x in Village.bridges do
		local p = VillageLayout.lower(x) - Vector3.new(0, 0, Village.riverOffset)
		table.insert(bridges, CFrame.new(p))
	end
	local sites: { [string]: CFrame } = {}
	for name, position in Village.sites :: { [string]: Vector3 } do
		sites[name] = CFrame.lookAt(position, Vector3.new(hub.X, position.Y, hub.Z))
	end
	return {
		roads = roads,
		plots = plots,
		hub = CFrame.new(hub),
		river = river,
		bridges = bridges,
		shortcuts = shortcuts,
		sites = sites,
	}
end

-- Punctul e în ogradă (sau la mai puțin de `margin` de gardul ei)?
function VillageLayout.contains(plot: PlotSpot, position: Vector3, margin: number?): boolean
	local p = plot.cframe:PointToObjectSpace(position)
	local m = margin or 0
	return math.abs(p.X) <= World.plotSize.X / 2 + m and math.abs(p.Z) <= World.plotSize.Z / 2 + m
end

local function segmentDistance(p: Vector3, a: Vector3, b: Vector3): number
	local flat = Vector3.new(p.X, 0, p.Z)
	local fa, fb = Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z)
	local ab = fb - fa
	local t = if ab.Magnitude < 1e-6 then 0 else math.clamp((flat - fa):Dot(ab) / ab:Dot(ab), 0, 1)
	return (flat - (fa + ab * t)).Magnitude
end

local function polylineDistance(p: Vector3, points: { Vector3 }): number
	local best = math.huge
	for i = 1, #points - 1 do
		best = math.min(best, segmentDistance(p, points[i], points[i + 1]))
	end
	return best
end

function VillageLayout.distanceToRoad(layout: Layout, p: Vector3): number
	local best = math.huge
	for _, road in layout.roads do
		best = math.min(best, polylineDistance(p, road.points))
	end
	return best
end

function VillageLayout.distanceToRiver(layout: Layout, p: Vector3): number
	return polylineDistance(p, layout.river)
end

-- Graful drumurilor (puncte la ~10 studs, intersecțiile legate) pentru drum mers între porți
type Graph = { nodes: { Vector3 }, edges: { [number]: { { number } } } }

local function graph(layout: Layout): Graph
	local nodes: { Vector3 } = {}
	local edges: { [number]: { { number } } } = {}
	local owner: { [number]: number } = {}
	local function link(i: number, j: number)
		local d = (nodes[i] - nodes[j]).Magnitude
		edges[i] = edges[i] or {}
		edges[j] = edges[j] or {}
		table.insert(edges[i], { j, d })
		table.insert(edges[j], { i, d })
	end
	local function node(p: Vector3, road: number): number
		for i, q in nodes do
			if (p - q).Magnitude < 4 then
				return i
			end
		end
		table.insert(nodes, p)
		owner[#nodes] = road
		return #nodes
	end
	local all = table.clone(layout.roads)
	for _, s in layout.shortcuts do
		table.insert(all, s)
	end
	for r, road in all do
		local previous: number? = nil
		for k = 1, #road.points - 1 do
			local a, b = road.points[k], road.points[k + 1]
			local n = math.max(1, math.floor((b - a).Magnitude / 10))
			for step = 0, n - 1 do
				local id = node(a:Lerp(b, step / n), r)
				if previous and previous ~= id then
					link(previous, id)
				end
				previous = id
			end
		end
		local last = node(road.points[#road.points], r)
		if previous and previous ~= last then
			link(previous, last)
		end
	end
	-- capetele de drum se leagă de cel mai apropiat punct al altui drum (intersecțiile)
	for r, road in all do
		for _, endPoint in { road.points[1], road.points[#road.points] } do
			local e, eDist = 0, math.huge
			local o, oDist = 0, math.huge
			for i, q in nodes do
				local d = (q - endPoint).Magnitude
				if d < eDist then
					e, eDist = i, d
				end
				if owner[i] ~= r and d < oDist then
					o, oDist = i, d
				end
			end
			if o > 0 and e > 0 and o ~= e and (nodes[o] - nodes[e]).Magnitude < 25 then
				link(e, o)
			end
		end
	end
	return { nodes = nodes, edges = edges }
end

local function attach(g: Graph, p: Vector3): number
	local best, bestDist = 1, math.huge
	for i, q in g.nodes do
		local d = (q - p).Magnitude
		if d < bestDist then
			best, bestDist = i, d
		end
	end
	table.insert(g.nodes, p)
	local id = #g.nodes
	g.edges[id] = { { best, bestDist } }
	g.edges[best] = g.edges[best] or {}
	table.insert(g.edges[best], { id, bestDist })
	return id
end

local function dijkstra(g: Graph, source: number): { [number]: number }
	local dist: { [number]: number } = { [source] = 0 }
	local done: { [number]: boolean } = {}
	while true do
		local u, best = nil, math.huge
		for node, d in dist do
			if not done[node] and d < best then
				u, best = node, d
			end
		end
		if not u then
			break
		end
		done[u] = true
		local out: { { number } } = g.edges[u] or {}
		for _, edge in out do
			local v, w = edge[1], edge[2]
			local nd = best + w
			if nd < (dist[v] or math.huge) then
				dist[v] = nd
			end
		end
	end
	return dist
end

-- Echitatea: variația distanței medii de la fiecare poartă la celelalte 7 (expunerea la raiduri) și a distanței
-- până la centru, pe drumurile reale.
function VillageLayout.fairness(layout: Layout): { exposureCV: number, exposureMaxMin: number, hubCV: number }
	local g = graph(layout)
	local gates = {}
	for _, plot in layout.plots do
		table.insert(gates, attach(g, plot.gate))
	end
	local hub = attach(g, layout.hub.Position)
	local fromHub = dijkstra(g, hub)
	local means, hubs = {}, {}
	for i, gate in gates do
		local d = dijkstra(g, gate)
		local sum = 0
		for j, other in gates do
			if i ~= j then
				sum += d[other]
			end
		end
		table.insert(means, sum / (#gates - 1))
		table.insert(hubs, fromHub[gate])
	end
	local function cv(list: { number }): number
		local mean = 0
		for _, v in list do
			mean += v
		end
		mean /= #list
		local var = 0
		for _, v in list do
			var += (v - mean) ^ 2
		end
		return math.sqrt(var / #list) / mean
	end
	local maxV, minV = -math.huge, math.huge
	for _, v in means do
		maxV, minV = math.max(maxV, v), math.min(minV, v)
	end
	return { exposureCV = cv(means), exposureMaxMin = maxV / minV, hubCV = cv(hubs) }
end

return VillageLayout
