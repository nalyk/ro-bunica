--!strict
-- Politicile Roblox pe jucător (PolicyService): unde cumpărăturile cu rezultate aleatorii sunt restricționate
-- (ArePaidRandomItemsRestricted) și unde schimbul de lucruri plătite nu e permis (IsPaidItemTradingAllowed).
-- Fără un răspuns valid jucătorul e tratat ca restricționat.
-- Nivelul de preț (MarketplaceService:GetUsersPriceLevelsAsync, 1–1000 = cât din prețul global plătește
-- jucătorul cu Managed Pricing): schimburile între regiuni cu prețuri diferite ar permite arbitrajul
-- (lei cumpărați ieftin, mutați la altcineva), deci se cer niveluri apropiate.

export type Policy = { randomRestricted: boolean, tradingAllowed: boolean, priceLevel: number? }

local Policy = {}

-- Boții de test și proprietarii fără jucător
Policy.OPEN = table.freeze({ randomRestricted = false, tradingAllowed = true, priceLevel = 1000 }) :: Policy

-- Diferența de nivel acceptată (25 din 1000 = 2,5% din preț): prea puțin ca arbitrajul să merite, dar
-- prietenii din regiuni cu prețuri aproape egale pot face schimburi
Policy.PRICE_TOLERANCE = 25

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

-- Schimb (valoare în ambele sensuri): amândoi au voie și au niveluri de preț apropiate
function Policy.canTrade(a: Policy, b: Policy): boolean
	local la, lb = a.priceLevel, b.priceLevel
	return a.tradingAllowed
		and b.tradingAllowed
		and la ~= nil
		and lb ~= nil
		and math.abs(la - lb) <= Policy.PRICE_TOLERANCE
end

-- Valoare într-un singur sens (leii cumpărătorului la vânzător): dinspre regiunea mai scumpă spre cea mai
-- ieftină, niciodată invers (recomandarea Roblox pentru cadouri)
function Policy.canGive(from: Policy, to: Policy): boolean
	local lf, lt = from.priceLevel, to.priceLevel
	return from.tradingAllowed
		and to.tradingAllowed
		and lf ~= nil
		and lt ~= nil
		and lf + Policy.PRICE_TOLERANCE >= lt
end

return Policy
