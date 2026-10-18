--!strict
-- Politicile Roblox pe jucător (PolicyService): unde cumpărăturile cu rezultate aleatorii sunt restricționate
-- (ArePaidRandomItemsRestricted) și unde schimbul de lucruri plătite nu e permis (IsPaidItemTradingAllowed).
-- Fără un răspuns valid jucătorul e tratat ca restricționat.

export type Policy = { randomRestricted: boolean, tradingAllowed: boolean }

local Policy = {}

-- Boții de test și proprietarii fără jucător
Policy.OPEN = table.freeze({ randomRestricted = false, tradingAllowed = true }) :: Policy

function Policy.fromInfo(ok: boolean, info: any): Policy
	if not ok or type(info) ~= "table" then
		return { randomRestricted = true, tradingAllowed = false }
	end
	return {
		randomRestricted = info.ArePaidRandomItemsRestricted ~= false,
		tradingAllowed = info.IsPaidItemTradingAllowed == true,
	}
end

-- Un permis sau produs marcat `random` (lei cumpărați, magazin reînnoit, vreme cu mutații) duce la
-- rezultate aleatorii și nu se arată celor restricționați.
function Policy.canBuy(item: { random: boolean? }, policy: Policy): boolean
	return not (item.random and policy.randomRestricted)
end

return Policy
