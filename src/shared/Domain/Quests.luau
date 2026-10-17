--!strict
-- Treburile zilei: 3 pe zi UTC, alese determinist din zi și UserId (aceleași pe orice server).
-- Progresul vine din evenimentele jocului (`record`); recompensa se ia din Caiet (`claim`).

local Config = script.Parent.Parent.Config
local Notebook = require(Config.Notebook)
local RandomUtil = require(script.Parent.Random)

export type Quest = { kind: string, goal: number, progress: number, claimed: boolean }
export type State = { day: number, list: { Quest }, bonusClaimed: boolean }
type Profile = { quests: State, seeds: { [string]: number } }

local Quests = {}

-- Treburile pentru o zi și un jucător, fără progres.
function Quests.forDay(day: number, userId: number): { Quest }
	local rng = RandomUtil.seeded(day * 7919 + math.abs(userId) % 1000003 + 1)
	local pool = table.clone(Notebook.quests.kinds) :: { any }
	local list: { Quest } = {}
	for _ = 1, math.min(Notebook.quests.perDay, #pool) do
		local index = math.floor(rng() * #pool) + 1
		local def = table.remove(pool, index)
		table.insert(list, { kind = def.kind, goal = def.goal, progress = 0, claimed = false })
	end
	return list
end

-- Aduce treburile la ziua curentă (o zi nouă le înlocuiește). Întoarce true dacă s-au schimbat.
function Quests.ensure(profile: Profile, day: number, userId: number): boolean
	if profile.quests.day == day and #profile.quests.list > 0 then
		return false
	end
	profile.quests = { day = day, list = Quests.forDay(day, userId), bonusClaimed = false }
	return true
end

-- Adaugă progres la treburile de tipul dat. Întoarce indicii treburilor terminate chiar acum.
function Quests.record(profile: Profile, kind: string, amount: number?): { number }
	local done = {}
	for index, quest in profile.quests.list do
		if quest.kind == kind and quest.progress < quest.goal then
			quest.progress = math.min(quest.goal, quest.progress + (amount or 1))
			if quest.progress >= quest.goal then
				table.insert(done, index)
			end
		end
	end
	return done
end

function Quests.reward(incomePerSecond: number): number
	return math.max(Notebook.quests.minReward, math.floor(incomePerSecond * Notebook.quests.rewardSeconds))
end

-- Ia recompensa unei treburi terminate. Întoarce leii sau nil (neterminată ori deja luată).
function Quests.claim(profile: Profile, index: number, incomePerSecond: number): number?
	local quest = profile.quests.list[index]
	if not quest or quest.claimed or quest.progress < quest.goal then
		return nil
	end
	quest.claimed = true
	return Quests.reward(incomePerSecond)
end

-- Bonusul pentru toate treburile zilei: o sămânță Rară sau Epică (determinist din zi). Nil dacă nu se poate.
function Quests.claimBonus(profile: Profile): string?
	local state = profile.quests
	if state.bonusClaimed or #state.list == 0 then
		return nil
	end
	for _, quest in state.list do
		if not quest.claimed then
			return nil
		end
	end
	state.bonusClaimed = true
	local seeds = Notebook.quests.bonusSeeds
	local seed = seeds[state.day % #seeds + 1]
	profile.seeds[seed] = (profile.seeds[seed] or 0) + 1
	return seed
end

return Quests
