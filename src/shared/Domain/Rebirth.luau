--!strict
-- Renașterea („Gospodăria nouă”): dai leii, semințele, plantele și creaturile pentru +50% venit permanent.
-- Rămân creatura cea mai valoroasă („de suflet”), îmbunătățirile, permisele, colecția și statisticile.

local Config = script.Parent.Parent.Config
local Notebook = require(Config.Notebook)
local EconomyConfig = require(Config.Economy)
local Economy = require(script.Parent.Economy)

type CreatureRecord = { uid: string, id: string, size: string, mutation: string? }
type Profile = {
	lei: number,
	rebirths: number,
	seeds: { [string]: number },
	beds: { [string]: any },
	pedestals: { [string]: CreatureRecord },
	cellar: { CreatureRecord },
}

local Rebirth = {}

-- Prețul următoarei renașteri (nil la nivelul maxim).
function Rebirth.cost(level: number): number?
	if level >= Notebook.rebirth.maxLevel then
		return nil
	end
	return Notebook.rebirth.baseCost * Notebook.rebirth.growth ^ level
end

function Rebirth.multiplier(level: number): number
	return 1 + level * Notebook.rebirth.incomeBonus
end

function Rebirth.canRebirth(profile: Profile): (boolean, string?)
	local cost = Rebirth.cost(profile.rebirths)
	if not cost then
		return false, "Max"
	elseif profile.lei < cost then
		return false, "NotEnoughLei"
	end
	return true, nil
end

-- Creatura cea mai valoroasă (după venit), oriunde ar fi.
function Rebirth.keepsake(profile: Profile): CreatureRecord?
	local best: CreatureRecord? = nil
	local bestValue = -1
	local function consider(record: CreatureRecord)
		local value = Economy.incomePerSecond(record)
		if value > bestValue or (value == bestValue and best and record.uid < best.uid) then
			best, bestValue = record, value
		end
	end
	for _, record in profile.pedestals do
		consider(record)
	end
	for _, record in profile.cellar do
		consider(record)
	end
	return best
end

-- Aplică renașterea. Întoarce creatura păstrată (pusă pe primul piedestal) sau nil dacă nu se poate.
function Rebirth.apply(profile: Profile): (boolean, CreatureRecord?)
	if not Rebirth.canRebirth(profile) then
		return false, nil
	end
	local kept = Rebirth.keepsake(profile)
	profile.rebirths += 1
	profile.lei = EconomyConfig.startingLei
	profile.seeds = { [Notebook.rebirth.giftSeed] = 1 }
	profile.beds = {}
	profile.pedestals = {}
	profile.cellar = {}
	if kept then
		profile.pedestals["1"] = kept
	end
	return true, kept
end

return Rebirth
