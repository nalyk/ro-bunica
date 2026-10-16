--!strict
-- Logica cumpărărilor pe Robux (fără Roblox): efectele permiselor (o singură dată pe profil), pachetele
-- de lei și chitanțele deja procesate (ProcessReceipt poate fi chemat de mai multe ori pentru aceeași plată).

local Config = require(script.Parent.Parent.Config.Monetization)
local Economy = require(script.Parent.Parent.Config.Economy)

type Profile = {
	pedestalCount: number,
	bedCount: number,
	cellarCapacity: number,
	passes: { [string]: boolean },
	receipts: { string },
}

local Monetization = {}

-- Lei dați de un pachet, după venitul curent al ogrăzii (lei pe secundă)
function Monetization.leiPack(key: string, incomePerSecond: number): number
	local pack = Config.leiPacks[key]
	if not pack then
		return 0
	end
	return math.max(pack.min, math.floor(incomePerSecond * pack.seconds))
end

-- Aplică efectele permanente ale unui permis, o singură dată. Întoarce true dacă a schimbat ceva.
function Monetization.applyPass(profile: Profile, key: string): boolean
	if profile.passes[key] or not Config.passByKey[key] then
		return false
	end
	profile.passes[key] = true
	if key == "vip" then
		profile.pedestalCount = math.min(profile.pedestalCount + Config.vipPedestals, Economy.maxPedestals)
	elseif key == "bigcellar" then
		profile.cellarCapacity += Config.bigCellarSlots
	elseif key == "gardener" then
		profile.bedCount = math.min(profile.bedCount + Config.gardenerBeds, Economy.maxBeds)
	end
	return true
end

function Monetization.wasProcessed(profile: Profile, purchaseId: string): boolean
	return table.find(profile.receipts, purchaseId) ~= nil
end

-- Ține minte o plată procesată (cele mai vechi se uită peste limită)
function Monetization.recordReceipt(profile: Profile, purchaseId: string)
	table.insert(profile.receipts, purchaseId)
	while #profile.receipts > Config.receiptsKept do
		table.remove(profile.receipts, 1)
	end
end

return Monetization
