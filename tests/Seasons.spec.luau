local Seasons = require(Shared.Domain.Seasons)

local function utc(y: number, m: number, d: number): number
	-- zile de la 1970 (algoritmul lui Howard Hinnant), apoi secunde
	local yy = if m <= 2 then y - 1 else y
	local era = yy // 400
	local yoe = yy - era * 400
	local mp = (m + 9) % 12
	local doy = (153 * mp + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return (era * 146097 + doe - 719468) * 86400 + 12 * 3600
end

describe("Seasons", function()
	it("Paștele ortodox: 2026 = 12 aprilie, 2027 = 2 mai, 2025 = 20 aprilie", function()
		local m, d = Seasons.orthodoxEaster(2026)
		expect(m).toBe(4)
		expect(d).toBe(12)
		m, d = Seasons.orthodoxEaster(2027)
		expect(m).toBe(5)
		expect(d).toBe(2)
		m, d = Seasons.orthodoxEaster(2025)
		expect(m).toBe(4)
		expect(d).toBe(20)
	end)
	it(
		"ferestrele: Mărțișor 1–14 martie, Drăgaica 20–27 iunie, Culesul 15 sept – 15 oct, Iarna 15 dec – 14 ian",
		function()
			expect(table.find(Seasons.active(utc(2027, 3, 5)), "Martisor") ~= nil).toBe(true)
			expect(table.find(Seasons.active(utc(2027, 3, 15)), "Martisor")).toBeNil()
			expect(table.find(Seasons.active(utc(2027, 6, 24)), "Dragaica") ~= nil).toBe(true)
			expect(table.find(Seasons.active(utc(2027, 10, 1)), "Culesul") ~= nil).toBe(true)
			expect(table.find(Seasons.active(utc(2027, 10, 16)), "Culesul")).toBeNil()
			expect(table.find(Seasons.active(utc(2026, 12, 31)), "Iarna") ~= nil).toBe(true)
			expect(table.find(Seasons.active(utc(2027, 1, 10)), "Iarna") ~= nil).toBe(true)
			expect(table.find(Seasons.active(utc(2027, 1, 20)), "Iarna")).toBeNil()
		end
	)
	it("Paștele ține de joi până duminica de după (11 zile)", function()
		expect(table.find(Seasons.active(utc(2026, 4, 12)), "Paste") ~= nil).toBe(true)
		expect(table.find(Seasons.active(utc(2026, 4, 9)), "Paste") ~= nil).toBe(true)
		expect(table.find(Seasons.active(utc(2026, 4, 19)), "Paste") ~= nil).toBe(true)
		expect(table.find(Seasons.active(utc(2026, 4, 25)), "Paste")).toBeNil()
	end)
	it("hramul: o zi pe lună, aleasă pentru fiecare server", function()
		local day = Seasons.hramDay(12345)
		expect(day >= 1 and day <= 28).toBe(true)
		expect(Seasons.hramDay(12345)).toBe(day)
		expect(table.find(Seasons.active(utc(2027, 2, day), day), "Hram") ~= nil).toBe(true)
		expect(table.find(Seasons.active(utc(2027, 2, day % 28 + 1), day), "Hram")).toBeNil()
	end)
	it("anotimpul (pentru pescuit și decor)", function()
		expect(Seasons.season(utc(2027, 4, 1))).toBe("Primavara")
		expect(Seasons.season(utc(2027, 7, 1))).toBe("Vara")
		expect(Seasons.season(utc(2027, 10, 1))).toBe("Toamna")
		expect(Seasons.season(utc(2027, 1, 1))).toBe("Iarna")
	end)
end)
