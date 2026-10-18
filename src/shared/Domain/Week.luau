--!strict
-- Săptămâna ISO (luni–duminică, UTC) pentru clasamentele săptămânale: „2026W43”. Prima săptămână a anului
-- e cea care conține prima joi, deci 1 ianuarie poate ține de săptămâna 52/53 a anului trecut.

local Week = {}

local DAY = 86400

local function civil(days: number): (number, number, number)
	-- zile de la 1970-01-01 → an, lună, zi (algoritmul lui Howard Hinnant)
	local z = days + 719468
	local era = (if z >= 0 then z else z - 146096) // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local y = yoe + era * 400
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local d = doy - (153 * mp + 2) // 5 + 1
	local m = if mp < 10 then mp + 3 else mp - 9
	return if m <= 2 then y + 1 else y, m, d
end

local function daysFrom(y: number, m: number, d: number): number
	local yy = if m <= 2 then y - 1 else y
	local era = (if yy >= 0 then yy else yy - 399) // 400
	local yoe = yy - era * 400
	local doy = (153 * (if m > 2 then m - 3 else m + 9) + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

function Week.key(now: number): string
	local days = now // DAY
	local weekday = (days + 3) % 7 -- 0 = luni
	local thursday = days - weekday + 3 -- joia din aceeași săptămână decide anul
	local year = civil(thursday)
	local week = (thursday - daysFrom(year, 1, 1)) // 7 + 1
	return string.format("%dW%02d", year, week)
end

-- Secunde până luni 00:00 UTC
function Week.secondsLeft(now: number): number
	local days = now // DAY
	local weekday = (days + 3) % 7
	return (days - weekday + 7) * DAY - now
end

return Week
