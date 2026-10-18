--!strict
-- Regulile comune ale mini-jocurilor: clasamentul, răsplățile, încurajările fantomelor.

local Minigames = require(script.Parent.Parent.Config.Minigames)

local Minigame = {}

-- Id-urile după scor (descrescător); la egalitate, cine a ajuns primul la scorul lui (`reachedAt` mai mic)
function Minigame.rank(scores: { [number]: number }, reachedAt: { [number]: number }?): { number }
	local ids = {}
	for id in scores do
		table.insert(ids, id)
	end
	local at = reachedAt or {}
	table.sort(ids, function(a, b)
		if scores[a] ~= scores[b] then
			return scores[a] > scores[b]
		end
		local ta, tb = at[a] or math.huge, at[b] or math.huge
		if ta ~= tb then
			return ta < tb
		end
		return a < b
	end)
	return ids
end

-- Lei pentru fiecare participant rămas până la final: participarea + podiumul (doar printre cei rămași)
-- Leii fiecăruia. Fără efort nu se plătește: participarea cere o acțiune (`acted`; nil = toți au jucat), iar
-- podiumul cere scor peste 0 și cel puțin doi jucători intrați (singur nu ai cu cine concura).
function Minigame.rewards(
	def: Minigames.Minigame,
	ranking: { number },
	present: { [number]: boolean },
	scores: { [number]: number }?,
	acted: { [number]: boolean }?
): { [number]: number }
	local result: { [number]: number } = {}
	local function participation(id: number): number
		return if acted == nil or acted[id] then def.rewards.participation else 0
	end
	-- câți au intrat în rundă (și cei plecați între timp): cine a avut un adversar poate urca pe podium
	local count = #ranking
	if scores then
		count = 0
		for _ in scores do
			count += 1
		end
	end
	if def.teams and scores then
		-- pe echipe: toți cei cu scorul cel mai mare (echipa câștigătoare) iau bonusul de câștig
		local top = -math.huge
		for id in present do
			top = math.max(top, scores[id] or 0)
		end
		for id in present do
			local won = (scores[id] or 0) == top and top > 0 and count >= 2
			result[id] = participation(id) + (if won then def.rewards.placements[1] or 0 else 0)
		end
		return result
	end
	local place = 0
	for _, id in ranking do
		if present[id] then
			place += 1
			local earned = scores == nil or (scores[id] or 0) > 0
			result[id] = participation(id)
				+ (if earned and count >= 2 then def.rewards.placements[place] or 0 else 0)
		end
	end
	for id in present do
		if result[id] == nil then
			result[id] = participation(id)
		end
	end
	return result
end

-- Plafonul pe oră al leilor din mini-jocuri (împotriva rundelor jucate doar pentru premiu)
Minigame.HOURLY_CAP = 600

function Minigame.capped(earnedThisHour: number, lei: number): number
	return math.max(0, math.min(lei, Minigame.HOURLY_CAP - earnedThisHour))
end

-- Fantomele (eliminații) încurajează: fiecare încurajare +5% la punctajul echipei, cel mult +25%
function Minigame.cheerMultiplier(cheers: number): number
	return 1 + math.min(cheers * Minigames.cheerStep, Minigames.cheerMax)
end

-- E un record? (mai mult decât cel vechi; un scor de zero nu e record)
function Minigame.isRecord(best: number?, score: number): boolean
	return score > 0 and score > (best or 0)
end

return Minigame
