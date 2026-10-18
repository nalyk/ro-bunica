local VillageClock = require(Shared.Domain.VillageClock)
local Happenings = require(Shared.Config.Happenings)
local Scatter = require(Shared.Domain.Scatter)

describe("VillageClock", function()
	it("alege doar întâmplări din faza cerută, cu pornirea peste 360–480 s", function()
		local rng = Scatter.rng(1)
		for i = 1, 60 do
			local id, startAt = VillageClock.next(10000 + i, "Night", 4, { Tren = 10000 }, rng)
			expect(id ~= nil).toBe(true)
			local def = Happenings.byId[id :: string]
			expect(def.phase == "Night" or def.phase == "Any").toBe(true)
			expect(startAt - (10000 + i) >= 360 and startAt - (10000 + i) <= 480).toBe(true)
		end
	end)
	it("nu repetă aceeași întâmplare de două ori la rând", function()
		local rng = Scatter.rng(7)
		local history = { Tren = 0 }
		local now = 100
		local last = nil
		for _ = 1, 40 do
			local id, startAt = VillageClock.next(now, "Day", 6, history, rng)
			expect(id ~= last).toBe(true)
			history[id :: string] = startAt
			last = id
			now = startAt + 600
		end
	end)
	it("respectă cooldown-ul fiecărei întâmplări", function()
		local rng = Scatter.rng(3)
		local now = 5000
		local history = { Tren = now }
		for _, def in Happenings.list do
			history[def.id] = now - 10 -- toate tocmai au fost
		end
		local id = VillageClock.next(now, "Day", 4, history, rng)
		expect(id).toBeNil()
	end)
	it("cu un singur jucător alege doar întâmplări care merg solo", function()
		local rng = Scatter.rng(11)
		for i = 1, 50 do
			local id =
				VillageClock.next(9000 + i, if i % 2 == 0 then "Day" else "Night", 1, { Tren = 9000 }, rng)
			if id then
				expect(Happenings.byId[id].minPlayers <= 1).toBe(true)
			end
		end
	end)
	it("trenul vine cel mult o dată pe oră, iar după o oră are prioritate", function()
		local rng = Scatter.rng(5)
		expect(VillageClock.next(4000, "Day", 3, { Tren = 4000 - 3700 }, rng)).toBe("Tren")
		local id = VillageClock.next(4000, "Day", 3, { Tren = 4000 - 1200 }, rng)
		expect(id ~= "Tren").toBe(true)
	end)
	it("răsplata: ceva pentru participare, mai mult pentru podium, nimic pentru cine n-a venit", function()
		expect(VillageClock.reward(false, nil)).toBe(0)
		local base = VillageClock.reward(true, nil)
		expect(base > 0).toBe(true)
		expect(VillageClock.reward(true, 1) > VillageClock.reward(true, 2)).toBe(true)
		expect(VillageClock.reward(true, 3) > base).toBe(true)
	end)
	it("alege doar dintre întâmplările permise (cele care au modul pe server)", function()
		local rng = Scatter.rng(13)
		for i = 1, 30 do
			local id = VillageClock.next(
				8000 + i * 1000,
				"Day",
				4,
				{ Tren = 8000 + i * 1000 },
				rng,
				{ Gaste = true }
			)
			expect(id == nil or id == "Gaste").toBe(true)
		end
		expect(VillageClock.next(8000, "Day", 4, { Tren = 0 }, rng, { Gaste = true })).toBe("Gaste")
	end)
end)
