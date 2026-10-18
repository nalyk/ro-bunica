--!strict
-- Calendarul sezonier al satului (după ora UTC): Mărțișorul, Paștele ortodox, Drăgaica, Culesul, Iarna și
-- hramul satului (o zi pe lună, alta pe fiecare server). Plus anotimpul, pentru pescuit și decor.

local Seasons = {}

-- Data civilă din zilele de la 1970 (algoritmul lui Howard Hinnant): an, lună, zi
local function civil(days: number): (number, number, number)
	local z = days + 719468
	local era = z // 146097
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
	local era = yy // 400
	local yoe = yy - era * 400
	local mp = (m + 9) % 12
	local doy = (153 * mp + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

function Seasons.date(unixTime: number): (number, number, number)
	return civil(unixTime // 86400)
end

-- Paștele ortodox (algoritmul iulian al lui Meeus, apoi + 13 zile în calendarul gregorian, valabil 1900–2099)
function Seasons.orthodoxEaster(year: number): (number, number)
	local a, b, c = year % 4, year % 7, year % 19
	local d = (19 * c + 15) % 30
	local e = (2 * a + 4 * b - d + 34) % 7
	local month = (d + e + 114) // 31
	local day = (d + e + 114) % 31 + 1
	local _, gm, gd = civil(daysFrom(year, month, day) + 13)
	return gm, gd
end

-- Ziua hramului (1–28), aceeași pe un server, diferită între servere
function Seasons.hramDay(serverSeed: number): number
	return (math.floor(serverSeed) * 7919) % 28 + 1
end

local function inRange(m: number, d: number, m1: number, d1: number, m2: number, d2: number): boolean
	local x, a, b = m * 100 + d, m1 * 100 + d1, m2 * 100 + d2
	return if a <= b then x >= a and x <= b else x >= a or x <= b
end

-- Sărbătorile de acum
function Seasons.active(unixTime: number, hramDay: number?): { string }
	local y, m, d = Seasons.date(unixTime)
	local list = {}
	if inRange(m, d, 3, 1, 3, 14) then
		table.insert(list, "Martisor")
	end
	local em, ed = Seasons.orthodoxEaster(y)
	local today = daysFrom(y, m, d)
	local easter = daysFrom(y, em, ed)
	if today >= easter - 3 and today <= easter + 7 then
		table.insert(list, "Paste")
	end
	if inRange(m, d, 6, 20, 6, 27) then
		table.insert(list, "Dragaica")
	end
	if inRange(m, d, 9, 15, 10, 15) then
		table.insert(list, "Culesul")
	end
	if inRange(m, d, 12, 15, 1, 14) then
		table.insert(list, "Iarna")
	end
	if hramDay and d == hramDay then
		table.insert(list, "Hram")
	end
	return list
end

function Seasons.season(unixTime: number): string
	local _, m = Seasons.date(unixTime)
	if m >= 3 and m <= 5 then
		return "Primavara"
	elseif m >= 6 and m <= 8 then
		return "Vara"
	elseif m >= 9 and m <= 11 then
		return "Toamna"
	end
	return "Iarna"
end

return Seasons
