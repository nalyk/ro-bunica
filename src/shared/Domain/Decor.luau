--!strict
-- Decorul ogrăzii: cumpărarea pe lei și așezarea pe sloturi (Config/Decor). `ownedDecor[id]` = câte bucăți ai,
-- `decor[slot]` = ce stă pe slot. O bucată stă pe un singur slot.

local DecorConfig = require(script.Parent.Parent.Config.Decor)

type Profile = { lei: number, decor: { [string]: string }, ownedDecor: { [string]: number } }

local Decor = {}

function Decor.price(id: string): number
	local item = DecorConfig.byId[id]
	return if item then item.price else math.huge
end

function Decor.canBuy(profile: Profile, id: string): (boolean, string?)
	if not DecorConfig.byId[id] then
		return false, "Unknown"
	end
	if profile.lei < Decor.price(id) then
		return false, "NotEnoughLei"
	end
	return true, nil
end

function Decor.buy(profile: Profile, id: string): boolean
	if not Decor.canBuy(profile, id) then
		return false
	end
	profile.lei -= Decor.price(id)
	profile.ownedDecor[id] = (profile.ownedDecor[id] or 0) + 1
	return true
end

local function placed(profile: Profile, id: string, except: string?): number
	local n = 0
	for slot, placedId in profile.decor do
		if placedId == id and slot ~= except then
			n += 1
		end
	end
	return n
end

function Decor.canPlace(profile: Profile, id: string, slotId: string): (boolean, string?)
	local item, slot = DecorConfig.byId[id], DecorConfig.slotById[slotId]
	if not item or not slot then
		return false, "Unknown"
	end
	if item.kind ~= slot.kind then
		return false, "WrongSlot"
	end
	if (profile.ownedDecor[id] or 0) == 0 then
		return false, "NotOwned"
	end
	return true, nil
end

-- Așază `id` pe slot. Dacă toate bucățile sunt deja puse, una e mutată de pe slotul ei.
function Decor.place(profile: Profile, id: string, slotId: string): boolean
	if not Decor.canPlace(profile, id, slotId) then
		return false
	end
	if profile.decor[slotId] ~= id and placed(profile, id) >= (profile.ownedDecor[id] or 0) then
		for s, placedId in profile.decor do
			if placedId == id then
				profile.decor[s] = nil
				break
			end
		end
	end
	profile.decor[slotId] = id
	return true
end

function Decor.remove(profile: Profile, slotId: string)
	profile.decor[slotId] = nil
end

function Decor.placedCount(profile: Profile): number
	local n = 0
	for _ in profile.decor do
		n += 1
	end
	return n
end

return Decor
