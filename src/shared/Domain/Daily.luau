--!strict
-- Recompensa zilnică pe serie: o zi nouă (UTC) dă recompensa zilei din serie; o zi sărită o ia de la capăt.
-- Ziua 7 dă o sămânță rară; după ziua 7, seria reîncepe de la ziua 1.

local Daily = {}

Daily.LENGTH = 7
Daily.LEI = { 100, 200, 400, 700, 1200, 2000, 3000 } -- lei pe ziua din serie
Daily.SEED_DAY7 = "GogoasaNinja" -- sămânța rară din ziua 7

type Profile = { lei: number, daily: { lastDay: number, streak: number }, seeds: { [string]: number } }

-- Ziua UTC (număr de zile de la epoca Unix)
function Daily.dayOf(unixSeconds: number): number
	return math.floor(unixSeconds / 86400)
end

export type Claim = { day: number, lei: number, seed: string? }

-- Revendică recompensa pentru ziua `today`, dacă n-a fost luată. Întoarce nil dacă a fost luată azi.
function Daily.claim(profile: Profile, today: number): Claim?
	local state = profile.daily
	if state.lastDay == today then
		return nil
	end
	local streak = if state.lastDay == today - 1 then state.streak % Daily.LENGTH + 1 else 1
	state.lastDay = today
	state.streak = streak
	local lei = Daily.LEI[streak]
	profile.lei += lei
	local seed = if streak == Daily.LENGTH then Daily.SEED_DAY7 else nil
	if seed then
		profile.seeds[seed] = (profile.seeds[seed] or 0) + 1
	end
	return { day = streak, lei = lei, seed = seed }
end

return Daily
