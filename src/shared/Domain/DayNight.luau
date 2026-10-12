--!strict
-- Faza ciclului zi/noapte pentru un timp scurs de la pornirea ciclului.

local DayNightConfig = require(script.Parent.Parent.Config.DayNight)

export type PhaseInfo = {
	phase: "Day" | "Night",
	secondsLeft: number,
	cycle: number, -- indexul ciclului (0, 1, 2…)
	progress: number, -- 0..1 în faza curentă
}

local DayNight = {}

function DayNight.cycleLength(): number
	return DayNightConfig.daySeconds + DayNightConfig.nightSeconds
end

function DayNight.at(elapsed: number): PhaseInfo
	local length = DayNight.cycleLength()
	local t = math.max(elapsed, 0)
	local cycle = math.floor(t / length)
	local inCycle = t - cycle * length
	if inCycle < DayNightConfig.daySeconds then
		return {
			phase = "Day",
			secondsLeft = DayNightConfig.daySeconds - inCycle,
			cycle = cycle,
			progress = inCycle / DayNightConfig.daySeconds,
		}
	end
	local intoNight = inCycle - DayNightConfig.daySeconds
	return {
		phase = "Night",
		secondsLeft = DayNightConfig.nightSeconds - intoNight,
		cycle = cycle,
		progress = intoNight / DayNightConfig.nightSeconds,
	}
end

return DayNight
