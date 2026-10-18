local NotifyPlan = require(Shared.Domain.NotifyPlan)

-- 2026-10-21 (miercuri) 10:00 UTC
local WEDNESDAY = 1792576800
local HOUR = 3600

describe("NotifyPlan", function()
	it("plantele care se coc în lipsa jucătorului: notificarea la coacere", function()
		local plan = NotifyPlan.choose(WEDNESDAY, { growSeconds = 3 * HOUR })
		expect(plan and plan.kind).toBe("grown")
		expect(plan and plan.due).toBe(WEDNESDAY + 3 * HOUR)
	end)

	it("prea repede (sub o oră) sau prea târziu (peste 20 de ore): fără notificare de coacere", function()
		expect(NotifyPlan.choose(WEDNESDAY, { growSeconds = 20 * 60 })).toBe(nil)
		expect(NotifyPlan.choose(WEDNESDAY, { growSeconds = 30 * HOUR })).toBe(nil)
	end)

	it("vineri seara: sâmbăta în sat e cea mai apropiată (cu 15 minute înainte de 16:00 UTC)", function()
		local friday = WEDNESDAY + 2 * 24 * HOUR + 8 * HOUR -- vineri 18:00
		local plan = NotifyPlan.choose(friday, {})
		expect(plan and plan.kind).toBe("saturday")
		expect(plan and plan.due).toBe(WEDNESDAY + 3 * 24 * HOUR + 6 * HOUR - 15 * 60)
	end)

	it("sâmbătă seara: bazarul de duminică, la 08:00 UTC", function()
		local saturday = WEDNESDAY + 3 * 24 * HOUR + 10 * HOUR -- sâmbătă 20:00
		local plan = NotifyPlan.choose(saturday, {})
		expect(plan and plan.kind).toBe("bazaar")
		expect(plan and plan.due).toBe(WEDNESDAY + 4 * 24 * HOUR - 2 * HOUR)
	end)

	it("dintre mai multe, cea mai apropiată", function()
		local friday = WEDNESDAY + 2 * 24 * HOUR + 8 * HOUR
		local plan = NotifyPlan.choose(friday, { growSeconds = 2 * HOUR })
		expect(plan and plan.kind).toBe("grown")
	end)

	it("miercuri, fără plante: nimic (sâmbăta e prea departe)", function()
		expect(NotifyPlan.choose(WEDNESDAY, {})).toBe(nil)
	end)
end)
