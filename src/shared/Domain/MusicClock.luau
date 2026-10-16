--!strict
-- Ceasul muzical al satului: grila de timp (optimi, măsuri, bucle), acordul curent și cuantizarea.
-- Pur (fără servicii): timpul vine din SoundService:GetMixerTime() în controller, aici e doar un număr.

local MusicClock = {}

export type Grid = {
	origin: number, -- momentul (timp de mixer) în care a început bucla 0
	bpm: number, -- pătrimi pe minut
	eighthsPerBar: number, -- 4 la 2/4
	eighthsPerLoop: number, -- 64 = 16 măsuri
}

function MusicClock.grid(origin: number, bpm: number, eighthsPerBar: number?, eighthsPerLoop: number?): Grid
	return {
		origin = origin,
		bpm = bpm,
		eighthsPerBar = eighthsPerBar or 4,
		eighthsPerLoop = eighthsPerLoop or 64,
	}
end

function MusicClock.eighth(grid: Grid): number
	return 30 / grid.bpm
end

function MusicClock.loopLength(grid: Grid): number
	return grid.eighthsPerLoop * MusicClock.eighth(grid)
end

-- Poziția (în optimi, fracționară) de la începutul grilei
function MusicClock.position(grid: Grid, time: number): number
	return (time - grid.origin) / MusicClock.eighth(grid)
end

-- Următoarea limită de grilă (multiplu de `unit` optimi) la cel puțin `lead` secunde după `time`
function MusicClock.nextBoundary(grid: Grid, time: number, unit: number, lead: number?): number
	local e = MusicClock.eighth(grid)
	local target = time + (lead or 0)
	local k = math.ceil((target - grid.origin) / (unit * e) - 1e-9)
	return grid.origin + k * unit * e
end

-- Măsura din buclă (0-based) la momentul dat
function MusicClock.barInLoop(grid: Grid, time: number): number
	local bars = grid.eighthsPerLoop // grid.eighthsPerBar
	local bar = math.floor(MusicClock.position(grid, time) / grid.eighthsPerBar + 1e-9)
	return bar % bars
end

-- Offsetul (secunde) în buclă la momentul dat: de aici pornește un strat care intră din mers
function MusicClock.offsetInLoop(grid: Grid, time: number): number
	local loop = MusicClock.loopLength(grid)
	return (time - grid.origin) % loop
end

-- Acordul curent: `roots` are, pe fiecare măsură, semitonurile fundamentalei față de Re
function MusicClock.chordRoot(roots: { number }, grid: Grid, time: number): number
	return roots[MusicClock.barInLoop(grid, time) + 1] or 0
end

function MusicClock.speedForSemitones(semitones: number): number
	return 2 ^ (semitones / 12)
end

-- Când cântăm un efect: pe următoarea șaisprezecime, dar niciodată cu mai mult de `maxDelay` întârziere
-- (răspunsul la acțiunea jucătorului contează mai mult decât ritmul).
function MusicClock.quantize(grid: Grid, time: number, lead: number, maxDelay: number): number
	local at = MusicClock.nextBoundary(grid, time, 0.5, lead)
	if at - time > maxDelay then
		return time + lead
	end
	return at
end

return MusicClock
