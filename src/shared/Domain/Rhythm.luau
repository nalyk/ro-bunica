--!strict
-- Jocurile pe ritm (zdrobitul strugurilor, hora, Discoteca): pista de bătăi și judecata unei apăsări.

local Rhythm = {}

Rhythm.PERFECT = 0.08 -- secunde față de bătaie
Rhythm.GOOD = 0.18

function Rhythm.judge(beatTime: number, pressTime: number): "Perfect" | "Bun" | "Ratat"
	local d = math.abs(pressTime - beatTime)
	if d <= Rhythm.PERFECT then
		return "Perfect"
	elseif d <= Rhythm.GOOD then
		return "Bun"
	end
	return "Ratat"
end

function Rhythm.points(judgement: string): number
	return if judgement == "Perfect" then 3 elseif judgement == "Bun" then 1 else 0
end

-- Bătăile pe `seconds` secunde la `bpm`: fiecare pătrime, plus contratimpi (optimi) aleși de seed, ca la horă
function Rhythm.track(seed: number, bpm: number, seconds: number): { number }
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local function roll(): number
		state = (state * 48271) % 2147483647
		return (state - 1) / 2147483646
	end
	local beat = 60 / bpm
	local beats = {}
	local t = beat
	while t <= seconds do
		table.insert(beats, t)
		if t + beat / 2 <= seconds and roll() < 0.18 then
			table.insert(beats, t + beat / 2)
		end
		t += beat
	end
	return beats
end

-- Indexul bătăii celei mai apropiate de `time`
function Rhythm.nearest(beats: { number }, time: number): number
	local best, bestD = 1, math.huge
	for i, b in beats do
		local d = math.abs(b - time)
		if d < bestD then
			best, bestD = i, d
		end
	end
	return best
end

return Rhythm
