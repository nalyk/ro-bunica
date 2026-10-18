--!strict
-- Ciocnitul ouălor (de Paști, ca la bunica): două ouă se ciocnesc, unul crapă. Tăria vine din ou (alb, roșu,
-- încondeiat, auriu), dar norocul contează mereu. Câștigătorul ia oul celuilalt (colecția de ouă).

local EggDuel = {}

EggDuel.EGGS = { "Alb", "Rosu", "Incondeiat", "Auriu" }
local STRENGTH = { Alb = 1, Rosu = 1.5, Incondeiat = 2.2, Auriu = 3 }

function EggDuel.strength(egg: string): number
	return STRENGTH[egg] or 1
end

-- Cine câștigă: șansa lui A = tăria lui / suma tăriilor
function EggDuel.resolve(eggA: string, eggB: string, rng: () -> number): "A" | "B"
	local a, b = EggDuel.strength(eggA), EggDuel.strength(eggB)
	return if rng() < a / (a + b) then "A" else "B"
end

-- Cel mai slab ou din colecție (alegerea implicită dacă jucătorul nu alege)
function EggDuel.weakest(eggs: { [string]: number }): string?
	for _, egg in EggDuel.EGGS do
		if (eggs[egg] or 0) > 0 then
			return egg
		end
	end
	return nil
end

return EggDuel
