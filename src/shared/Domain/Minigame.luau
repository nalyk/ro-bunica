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
function Minigame.rewards(
	def: Minigames.Minigame,
	ranking: { number },
	present: { [number]: boolean },
	scores: { [number]: number }?
): { [number]: number }
	local result: { [number]: number } = {}
	if def.teams and scores then
		-- pe echipe: toți cei cu scorul cel mai mare (echipa câștigătoare) iau bonusul de câștig
		local top = -math.huge
		for id in present do
			top = math.max(top, scores[id] or 0)
		end
		for id in present do
			local won = (scores[id] or 0) == top and top > 0
			result[id] = def.rewards.participation + (if won then def.rewards.placements[1] or 0 else 0)
		end
		return result
	end
	local place = 0
	for _, id in ranking do
		if present[id] then
			place += 1
			result[id] = def.rewards.participation + (def.rewards.placements[place] or 0)
		end
	end
	for id in present do
		if result[id] == nil then
			result[id] = def.rewards.participation
		end
	end
	return result
end

-- Fantomele (eliminații) încurajează: fiecare încurajare +5% la punctajul echipei, cel mult +25%
function Minigame.cheerMultiplier(cheers: number): number
	return 1 + math.min(cheers * Minigames.cheerStep, Minigames.cheerMax)
end

return Minigame
