--!strict
-- Țară, țară, vrem ostași (2 echipe, până la 4v4, 2 minute, pe terenul școlii): fiecare echipă stă în lanț, ținută
-- de mână (frânghii între coechipieri). Echipele cheamă pe rând un „ostaș” din echipa cealaltă: el aleargă spre
-- lanț. Dacă trece printre doi cu viteză (peste prag), rupe lanțul și ia unul din ei în echipa lui; dacă nu,
-- rămâne la ei. La final câștigă echipa mai numeroasă.

local Kit = require(script.Parent.Parent.Happenings.Kit)
local Actors = require(script.Parent.Parent.Actors)

local Ostasi = {}

Ostasi.BREAK_SPEED = 13 -- studs/s la trecerea prin lanț
Ostasi.GAP = 4
Ostasi.SIDE = 15 -- jumătatea distanței dintre lanțuri
local RUN_SECONDS = 10

local function members(match: any, team: string): { any }
	local list = {}
	for _, owner in match.players do
		if match.data.team[owner] == team then
			table.insert(list, owner)
		end
	end
	return list
end

-- Așază echipa în lanț și leagă vecinii cu frânghii
local function formChain(match: any, team: string)
	for _, rope in match.data.ropes[team] or {} do
		rope:Destroy()
	end
	match.data.ropes[team] = {}
	local list = members(match, team)
	local side = if team == "A" then -1 else 1
	for i, owner in list do
		local offset = (i - (#list + 1) / 2) * Ostasi.GAP
		local cf = match.arena
			* CFrame.new(offset, 3, side * Ostasi.SIDE)
			* CFrame.Angles(0, if team == "A" then 0 else math.pi, 0)
		local character = owner.actor and Actors.characterOf(owner.actor)
		if character and owner ~= match.data.runner then
			character:PivotTo(cf)
		end
	end
	for i = 1, #list - 1 do
		local a, b = Kit.root(list[i]), Kit.root(list[i + 1])
		if a and b then
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Parent = a
			a1.Parent = b
			local rope = Instance.new("RopeConstraint")
			rope.Attachment0 = a0
			rope.Attachment1 = a1
			rope.Length = Ostasi.GAP + 1
			rope.Visible = true
			rope.Color = BrickColor.new("Bright red")
			rope.Thickness = 0.15
			rope.Parent = match.folder
			table.insert(match.data.ropes[team], rope)
			table.insert(match.data.ropes[team], a0)
			table.insert(match.data.ropes[team], a1)
		end
	end
end

local function publish(match: any)
	local teams = {}
	for owner, team in match.data.team do
		teams[tostring(owner.userId)] = team
	end
	match.publish({
		teams = teams,
		calling = match.data.calling,
		runner = match.data.runner and match.data.runner.userId,
		sizes = { A = #members(match, "A"), B = #members(match, "B") },
	})
end

-- Echipa care cheamă alege un ostaș din cealaltă
local function call(match: any)
	match.data.calling = if match.data.calling == "A" then "B" else "A"
	local other = if match.data.calling == "A" then "B" else "A"
	local candidates = members(match, other)
	if #candidates == 0 or #members(match, match.data.calling) < 2 then
		match.finish()
		return
	end
	local runner = candidates[match.data.rng:NextInteger(1, #candidates)]
	match.data.runner = runner
	match.data.runUntil = os.clock() + RUN_SECONDS
	match.data.last = nil
	formChain(match, "A")
	formChain(match, "B")
	-- ostașul pornește din fața lanțului lui, spre lanțul care l-a chemat
	local character = runner.actor and Actors.characterOf(runner.actor)
	if character then
		local side = if other == "A" then -1 else 1
		character:PivotTo(match.arena * CFrame.new(0, 3, side * (Ostasi.SIDE - 4)))
	end
	publish(match)
end

function Ostasi.setup(match: any)
	match.data.rng = Random.new()
	match.data.team = {}
	match.data.ropes = {}
	for i, owner in match.players do
		match.data.team[owner] = if i % 2 == 1 then "A" else "B"
	end
	match.data.calling = "B"
	call(match)
end

function Ostasi.teamOf(match: any, owner: any): string
	return match.data.team[owner] or "A"
end

-- Segmentele lanțului echipei (între rădăcinile coechipierilor vecini)
function Ostasi.links(match: any, team: string): { { any } }
	local list = members(match, team)
	local links = {}
	for i = 1, #list - 1 do
		table.insert(links, { list[i], list[i + 1] })
	end
	return links
end

-- Segmentele [p, q] și [a, b] se intersectează (în plan)?
local function crosses(p: Vector3, q: Vector3, a: Vector3, b: Vector3): boolean
	local function cross(o: Vector3, u: Vector3, v: Vector3): number
		return (u.X - o.X) * (v.Z - o.Z) - (u.Z - o.Z) * (v.X - o.X)
	end
	local d1, d2 = cross(a, b, p), cross(a, b, q)
	local d3, d4 = cross(p, q, a), cross(p, q, b)
	return ((d1 > 0) ~= (d2 > 0)) and ((d3 > 0) ~= (d4 > 0))
end

function Ostasi.tick(match: any, dt: number)
	local runner = match.data.runner
	if not runner then
		return
	end
	local root = Kit.root(runner)
	if not root then
		call(match)
		return
	end
	local position = root.Position
	local last = match.data.last
	match.data.last = position
	if last then
		local speed = Vector3.new(position.X - last.X, 0, position.Z - last.Z).Magnitude / math.max(dt, 1e-3)
		for _, link in Ostasi.links(match, match.data.calling) do
			local a, b = Kit.root(link[1]), Kit.root(link[2])
			if a and b and crosses(last, position, a.Position, b.Position) then
				if speed >= Ostasi.BREAK_SPEED then
					-- lanțul s-a rupt: ostașul ia unul dintre cei doi în echipa lui
					local taken = link[match.data.rng:NextInteger(1, 2)]
					match.data.team[taken] = match.data.team[runner]
					match.score(runner, 1)
				else
					match.data.team[runner] = match.data.calling -- prea încet: rămâne la ei
				end
				call(match)
				return
			end
		end
	end
	if os.clock() >= match.data.runUntil then
		match.data.team[runner] = match.data.calling -- n-a îndrăznit: rămâne la ei
		call(match)
	end
end

function Ostasi.finish(match: any): { [number]: number }
	local sizes = { A = #members(match, "A"), B = #members(match, "B") }
	local scores = {}
	for owner, team in match.data.team do
		scores[owner.userId] = sizes[team] * 100 -- același scor pentru toată echipa (bonusul de câștig e al echipei)
	end
	return scores
end

return Ostasi
