--!strict
-- Un traseu cu porți (cursa cu roaba, obby-ul morii): porțile se iau în ordine, viteza imposibilă între porți
-- e o scurtătură (înapoi la ultima poartă, ca anti-teleportul), ieșirea de pe culoar la fel.

export type Run = {
	gates: { Vector3 },
	radius: number, -- cât de aproape de poartă trebuie să treci
	corridor: number, -- cât de departe de traseu poți să te abați
	next: number, -- indexul porții următoare
	lastAt: number, -- momentul ultimei porți
	finishedAt: number?,
}

local Course = {}

Course.MAX_SPEED = 60 -- studs/s între două porți (fuga cu roaba la vale nu trece de atât)

function Course.new(gates: { Vector3 }, radius: number, corridor: number, startedAt: number): Run
	return {
		gates = gates,
		radius = radius,
		corridor = corridor,
		next = 2,
		lastAt = startedAt,
		finishedAt = nil,
	}
end

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function segmentDistance(p: Vector3, a: Vector3, b: Vector3): number
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
	local t = if ab:Dot(ab) > 0 then math.clamp(ap:Dot(ab) / ab:Dot(ab), 0, 1) else 0
	return (ap - ab * t).Magnitude
end

-- E punctul mai departe de traseu decât culoarul?
function Course.offCourse(gates: { Vector3 }, p: Vector3, corridor: number): boolean
	local best = math.huge
	for i = 1, #gates - 1 do
		best = math.min(best, segmentDistance(p, gates[i], gates[i + 1]))
	end
	return best > corridor
end

-- Poziția la momentul `now`: "gate" (poartă luată), "finish", "cheat" (scurtătură), "off" (în afara
-- traseului) sau "none"
function Course.update(run: Run, position: Vector3, now: number): string
	if run.finishedAt then
		return "none"
	end
	if Course.offCourse(run.gates, position, run.corridor) then
		return "off"
	end
	local gate = run.gates[run.next]
	if not gate or flat(position, gate) > run.radius then
		return "none"
	end
	local previous = run.gates[run.next - 1]
	local elapsed = math.max(now - run.lastAt, 1e-3)
	if flat(gate, previous) / elapsed > Course.MAX_SPEED then
		return "cheat"
	end
	run.lastAt = now
	run.next += 1
	if run.next > #run.gates then
		run.finishedAt = now
		return "finish"
	end
	return "gate"
end

-- Unde reapare cine a ieșit de pe traseu sau a trișat: la ultima poartă luată
function Course.respawnPoint(run: Run): Vector3
	return run.gates[math.max(1, run.next - 1)]
end

return Course
