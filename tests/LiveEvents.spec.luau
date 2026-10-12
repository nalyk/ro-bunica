local LiveEvents = require(Shared.Domain.LiveEvents)
local Growth = require(Shared.Domain.Growth)

-- 2026-10-17 este sâmbătă. 16:00 UTC = 1792252800 + 16 * 3600
local SATURDAY_MIDNIGHT = 1792195200
local schedule = { weekday = 6, startHourUtc = 16, durationMinutes = 60 }

describe("LiveEvents", function()
	it("calculează ziua săptămânii corect", function()
		-- 1970-01-01 (joi): secunde în săptămână = 4 zile
		expect(LiveEvents.secondsIntoWeek(0)).toBe(4 * 86400)
		expect(LiveEvents.secondsIntoWeek(SATURDAY_MIDNIGHT)).toBe(6 * 86400)
	end)
	it("e activ sâmbăta între 16 și 17 UTC", function()
		local active, endsAt = LiveEvents.activeWindow(schedule, SATURDAY_MIDNIGHT + 16 * 3600 + 120)
		expect(active).toBe(true)
		expect(endsAt).toBe(SATURDAY_MIDNIGHT + 17 * 3600)
		expect((LiveEvents.activeWindow(schedule, SATURDAY_MIDNIGHT + 17 * 3600))).toBe(false)
		expect((LiveEvents.activeWindow(schedule, SATURDAY_MIDNIGHT + 15 * 3600))).toBe(false)
	end)
	it("următorul început", function()
		local t = SATURDAY_MIDNIGHT + 10 * 3600
		expect(LiveEvents.nextStart(schedule, t)).toBe(SATURDAY_MIDNIGHT + 16 * 3600)
		local after = SATURDAY_MIDNIGHT + 18 * 3600
		expect(LiveEvents.nextStart(schedule, after)).toBe(SATURDAY_MIDNIGHT + 16 * 3600 + 7 * 86400)
	end)
	it("exclusivitatea se rotește săptămânal", function()
		local a = LiveEvents.exclusiveFor({ "A", "B" }, SATURDAY_MIDNIGHT)
		local b = LiveEvents.exclusiveFor({ "A", "B" }, SATURDAY_MIDNIGHT + 7 * 86400)
		expect(a ~= b).toBe(true)
		expect(LiveEvents.exclusiveFor({}, 0)).toBeNil()
	end)
end)

describe("Growth offline", function()
	it("crește cât a lipsit, plafonat", function()
		local plant = { seedId = "CartofelAgent", size = "Normal", grown = 0 }
		Growth.advanceOffline(plant, 10, 3600)
		expect(plant.grown).toBe(10)
		local big = { seedId = "DovleacDJ", size = "Normal", grown = 0 }
		Growth.advanceOffline(big, 100000, 600)
		expect(big.grown).toBe(600)
	end)
end)
