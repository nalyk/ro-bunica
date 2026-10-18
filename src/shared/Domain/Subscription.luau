--!strict
-- Abonamentul „Prietenii Bunicii” (Roblox Subscriptions): doar cosmetice, cât ține abonamentul — ținuta
-- de aur a Bunicii și titlul „Prietenul Bunicii”. Nicio putere în joc (VISION, liniile roșii).

local Subscription = {}

Subscription.OUTFIT = "aur"
Subscription.TITLE = "prietenBunicii"

type OutfitLike = { subscriber: boolean? }

function Subscription.canWear(outfit: OutfitLike, owned: boolean, subscribed: boolean): boolean
	if outfit.subscriber then
		return subscribed
	end
	return owned
end

-- Ținutele abonaților nu se cumpără pe lei
function Subscription.canBuy(outfit: OutfitLike): boolean
	return outfit.subscriber ~= true
end

return Subscription
