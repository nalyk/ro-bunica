--!strict
-- Ce notificare primește un jucător după ce pleacă (Roblox permite una pe zi): cea mai apropiată dintre
-- „plantele tale s-au copt”, „sâmbăta în sat începe” (cu 15 minute înainte) și „bazarul de duminică s-a
-- deschis”. Doar între o oră și maximum de așteptare: nimic imediat, nimic peste zile întregi.

local NotifyPlan = {}

export type Kind = "grown" | "saturday" | "bazaar"
export type Plan = { kind: Kind, due: number }
export type Info = { growSeconds: number? }

local HOUR = 3600
local DAY = 24 * HOUR
NotifyPlan.MIN_DELAY = HOUR
NotifyPlan.MAX_GROW = 20 * HOUR
NotifyPlan.MAX_EVENT = 72 * HOUR
NotifyPlan.SATURDAY_HOUR = 16 -- UTC, „Sâmbăta în sat” (Config/LiveEvents)
NotifyPlan.SUNDAY_HOUR = 8 -- UTC, bazarul mare se deschide pentru dimineața Europei
NotifyPlan.LEAD = 15 * 60

-- Următorul moment (≥ now) din săptămână: ziua 0 = duminică … 6 = sâmbătă (UTC), la ora dată
local function nextWeekly(now: number, weekday: number, hour: number): number
	local dayStart = now - now % DAY
	local today = (dayStart // DAY + 4) % 7 -- 1970-01-01 a fost joi
	local at = dayStart + ((weekday - today) % 7) * DAY + hour * HOUR
	return if at < now then at + 7 * DAY else at
end

function NotifyPlan.choose(now: number, info: Info): Plan?
	local candidates: { Plan } = {}
	local grow = info.growSeconds
	if grow and grow >= NotifyPlan.MIN_DELAY and grow <= NotifyPlan.MAX_GROW then
		table.insert(candidates, { kind = "grown", due = now + grow })
	end
	local saturday = nextWeekly(now, 6, NotifyPlan.SATURDAY_HOUR) - NotifyPlan.LEAD
	if saturday - now >= NotifyPlan.MIN_DELAY and saturday - now <= NotifyPlan.MAX_EVENT then
		table.insert(candidates, { kind = "saturday", due = saturday })
	end
	local sunday = nextWeekly(now, 0, NotifyPlan.SUNDAY_HOUR)
	if sunday - now >= NotifyPlan.MIN_DELAY and sunday - now <= NotifyPlan.MAX_EVENT then
		table.insert(candidates, { kind = "bazaar", due = sunday })
	end
	local best: Plan? = nil
	for _, plan in candidates do
		if not best or plan.due < best.due then
			best = plan
		end
	end
	return best
end

return NotifyPlan
