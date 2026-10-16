--!strict
-- Logica îmbunătățirilor ogrăzii (fără Roblox): preț, disponibilitate, cumpărare și efecte.

local Config = require(script.Parent.Parent.Config.Upgrades)
local Economy = require(script.Parent.Parent.Config.Economy)
local Defense = require(script.Parent.Parent.Config.Defense)

type Profile = {
	lei: number,
	upgrades: { [string]: number },
	pedestalCount: number,
	bedCount: number,
	cellarCapacity: number,
}

local Upgrades = {}

-- Rotunjire la două cifre semnificative (prețuri „curate”: 150, 320, 6.700, 1.200.000)
local function round2(value: number): number
	if value < 100 then
		return math.floor(value + 0.5)
	end
	local magnitude = 10 ^ (math.floor(math.log10(value)) - 1)
	return math.floor(value / magnitude + 0.5) * magnitude
end

function Upgrades.level(profile: Profile, id: string): number
	return profile.upgrades[id] or 0
end

-- Prețul nivelului următor (nil dacă nu se mai poate cumpăra)
function Upgrades.nextCost(profile: Profile, id: string): number?
	local def = Config.byId[id]
	if not def then
		return nil
	end
	local level = Upgrades.level(profile, id)
	if level >= def.maxLevel then
		return nil
	end
	if id == "pedestal" and profile.pedestalCount >= Economy.maxPedestals then
		return nil
	end
	if id == "bed" and profile.bedCount >= Economy.maxBeds then
		return nil
	end
	return round2(def.baseCost * def.growth ^ level)
end

export type BuyResult = "ok" | "max" | "lei" | "unknown"

function Upgrades.buy(profile: Profile, id: string): (BuyResult, number?)
	if not Config.byId[id] then
		return "unknown", nil
	end
	local cost = Upgrades.nextCost(profile, id)
	if not cost then
		return "max", nil
	end
	if profile.lei < cost then
		return "lei", cost
	end
	profile.lei -= cost
	profile.upgrades[id] = Upgrades.level(profile, id) + 1
	if id == "pedestal" then
		profile.pedestalCount = math.min(profile.pedestalCount + 1, Economy.maxPedestals)
	elseif id == "bed" then
		profile.bedCount = math.min(profile.bedCount + 1, Economy.maxBeds)
	elseif id == "cellar" then
		profile.cellarCapacity += Config.cellarPerLevel
	end
	return "ok", cost
end

-- Efectele pe luptă (ammo e citit direct din upgrades.ammo de SlipperService)
function Upgrades.regenSeconds(profile: Profile): number
	return Defense.slipper.regenSeconds - Config.regenPerLevel * Upgrades.level(profile, "regen")
end

function Upgrades.dogSlow(profile: Profile): number
	local level = Upgrades.level(profile, "dog")
	return if level > 0 then Config.dogSlow[level] else 1
end

function Upgrades.suspicionMultiplier(profile: Profile): number
	return 1 + Config.sharpSuspicion * Upgrades.level(profile, "sharp")
end

return Upgrades
