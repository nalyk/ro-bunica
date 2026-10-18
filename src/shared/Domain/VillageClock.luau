--!strict
-- Ceasul satului: următoarea întâmplare (Config/Happenings) și răsplata ei.

local Happenings = require(script.Parent.Parent.Config.Happenings)

local VillageClock = {}

-- Următoarea întâmplare și momentul ei. `history[id]` = ultima pornire; `rng()` ∈ [0, 1).
-- nil dacă nicio întâmplare nu e eligibilă (atunci ceasul reîncearcă mai târziu). `allowed`: doar acestea.
function VillageClock.next(
	now: number,
	phase: string,
	players: number,
	history: { [string]: number },
	rng: () -> number,
	allowed: { [string]: boolean }?
): (string?, number)
	local startAt = now + Happenings.minGap + rng() * (Happenings.maxGap - Happenings.minGap)
	local train = Happenings.byId.Tren
	local function permitted(id: string): boolean
		return allowed == nil or allowed[id] == true
	end
	if
		permitted("Tren")
		and now - (history.Tren or -math.huge) >= train.cooldownSeconds
		and players >= train.minPlayers
	then
		return "Tren", startAt
	end
	-- ultima întâmplare (cea mai recentă pornire) nu se repetă imediat
	local lastId, lastAt = nil, -math.huge
	for id, at in history do
		if at > lastAt then
			lastId, lastAt = id, at
		end
	end
	local options, total = {}, 0
	for _, def in Happenings.list do
		local eligible = def.weight > 0
			and permitted(def.id)
			and (def.phase == phase or def.phase == "Any")
			and players >= def.minPlayers
			and def.id ~= lastId
			and now - (history[def.id] or -math.huge) >= def.cooldownSeconds
		if eligible then
			table.insert(options, def)
			total += def.weight
		end
	end
	if total == 0 then
		return nil, startAt
	end
	local roll = rng() * total
	for _, def in options do
		roll -= def.weight
		if roll < 0 then
			return def.id, startAt
		end
	end
	return options[#options].id, startAt
end

-- Lei pentru un jucător: participarea plus podiumul (locurile 1–3)
function VillageClock.reward(participation: boolean, placement: number?): number
	if not participation then
		return 0
	end
	return Happenings.participation + (if placement then Happenings.podium[placement] or 0 else 0)
end

return VillageClock
