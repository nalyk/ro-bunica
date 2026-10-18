--!strict
-- Îngrijirea creaturilor: fericirea (0–100, 60 la început) scade încet cât joci; hrana și mângâierea o cresc.
-- O creatură fericită (≥ 80) dă +10% venit; una nefericită nu pierde nimic (fără pedeapsă, doar bonus).

local Care = {}

Care.START = 60
Care.HAPPY = 80
Care.BONUS = 1.1
Care.PET = 5
Care.PET_COOLDOWN = 30
Care.DECAY_PER_HOUR = 1
Care.FOOD = { peste = 15, placinta = 25, branza = 10 } :: { [string]: number }

type Record = { happiness: number?, lastPet: number? }

function Care.happiness(record: Record): number
	return record.happiness or Care.START
end

function Care.multiplier(happiness: number): number
	return if happiness >= Care.HAPPY then Care.BONUS else 1
end

function Care.feed(record: Record, food: string): boolean
	local value = Care.FOOD[food]
	if not value then
		return false
	end
	record.happiness = math.min(100, Care.happiness(record) + value)
	return true
end

function Care.pet(record: Record, now: number): boolean
	if record.lastPet and now - record.lastPet < Care.PET_COOLDOWN then
		return false
	end
	record.lastPet = now
	record.happiness = math.min(100, Care.happiness(record) + Care.PET)
	return true
end

function Care.decay(record: Record, seconds: number)
	record.happiness = math.max(0, Care.happiness(record) - Care.DECAY_PER_HOUR * seconds / 3600)
end

return Care
