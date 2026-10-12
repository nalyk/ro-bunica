--!strict
-- Calendarul evenimentelor săptămânale, din timpul Unix (UTC). Fără os.date: pur aritmetic, testabil.

local WEEK = 7 * 86400

local LiveEvents = {}

-- Secunde de la începutul săptămânii (duminică 00:00 UTC). 1 ianuarie 1970 a fost joi (ziua 4).
function LiveEvents.secondsIntoWeek(unix: number): number
	local days = math.floor(unix / 86400)
	local weekday = (days + 4) % 7
	return weekday * 86400 + (unix % 86400)
end

-- Numărul săptămânii (pentru rotația exclusivităților).
function LiveEvents.weekIndex(unix: number): number
	return math.floor((unix + 4 * 86400) / WEEK)
end

export type Schedule = { weekday: number, startHourUtc: number, durationMinutes: number }

-- Evenimentul e activ acum? Întoarce (activ, momentul de final în timp Unix).
function LiveEvents.activeWindow(event: Schedule, unix: number): (boolean, number)
	local start = event.weekday * 86400 + event.startHourUtc * 3600
	local duration = event.durationMinutes * 60
	local into = LiveEvents.secondsIntoWeek(unix)
	local offset = (into - start) % WEEK
	if offset < duration then
		return true, unix - offset + duration
	end
	return false, 0
end

-- Următorul început al evenimentului (timp Unix), strict după `unix` dacă nu e activ.
function LiveEvents.nextStart(event: Schedule, unix: number): number
	local start = event.weekday * 86400 + event.startHourUtc * 3600
	local into = LiveEvents.secondsIntoWeek(unix)
	local delta = (start - into) % WEEK
	return unix + delta
end

-- Exclusivitatea săptămânii, prin rotație.
function LiveEvents.exclusiveFor(exclusives: { string }, unix: number): string?
	if #exclusives == 0 then
		return nil
	end
	return exclusives[(LiveEvents.weekIndex(unix) % #exclusives) + 1]
end

return LiveEvents
