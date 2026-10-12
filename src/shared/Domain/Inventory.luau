--!strict
-- Operații pe creaturile din profil: piedestale (expuse) și beci (ascunse).
-- Cheile piedestalelor sunt string-uri ("1".."N"), ca profilul să fie sigur pentru DataStore.

local DataTemplate = require(script.Parent.Parent.Config.DataTemplate)

type Profile = DataTemplate.Profile
type CreatureRecord = DataTemplate.CreatureRecord

local Inventory = {}

function Inventory.newRecord(
	profile: Profile,
	ownerId: number,
	id: string,
	size: string,
	mutation: string?
): CreatureRecord
	profile.uidCounter += 1
	return {
		uid = string.format("%d-%d", ownerId, profile.uidCounter),
		id = id,
		size = size,
		mutation = mutation,
	}
end

function Inventory.freePedestal(profile: Profile): string?
	for index = 1, profile.pedestalCount do
		local key = tostring(index)
		if profile.pedestals[key] == nil then
			return key
		end
	end
	return nil
end

function Inventory.cellarHasRoom(profile: Profile): boolean
	return #profile.cellar < profile.cellarCapacity
end

-- Pune o creatură nouă: întâi pe un piedestal liber, apoi în beci.
-- Întoarce ("pedestal", cheie), ("cellar", nil) sau (nil, nil) dacă totul e plin.
function Inventory.place(profile: Profile, record: CreatureRecord): (string?, string?)
	local key = Inventory.freePedestal(profile)
	if key then
		profile.pedestals[key] = record
		return "pedestal", key
	end
	if Inventory.cellarHasRoom(profile) then
		table.insert(profile.cellar, record)
		return "cellar", nil
	end
	return nil, nil
end

function Inventory.takeFromPedestal(profile: Profile, key: string): CreatureRecord?
	local record = profile.pedestals[key]
	profile.pedestals[key] = nil
	return record
end

function Inventory.findPedestal(profile: Profile, uid: string): string?
	for key, record in profile.pedestals do
		if record.uid == uid then
			return key
		end
	end
	return nil
end

function Inventory.findCellar(profile: Profile, uid: string): number?
	for index, record in profile.cellar do
		if record.uid == uid then
			return index
		end
	end
	return nil
end

function Inventory.moveToCellar(profile: Profile, key: string): boolean
	local record = profile.pedestals[key]
	if not record or not Inventory.cellarHasRoom(profile) then
		return false
	end
	profile.pedestals[key] = nil
	table.insert(profile.cellar, record)
	return true
end

-- Mută din beci pe un piedestal (cel cerut, dacă e liber, altfel primul liber).
function Inventory.moveToPedestal(profile: Profile, uid: string, wantedKey: string?): string?
	local index = Inventory.findCellar(profile, uid)
	if not index then
		return nil
	end
	local key = wantedKey
	if key == nil or profile.pedestals[key] ~= nil or (tonumber(key) or 0) > profile.pedestalCount then
		key = Inventory.freePedestal(profile)
	end
	if not key then
		return nil
	end
	profile.pedestals[key] = table.remove(profile.cellar, index) :: CreatureRecord
	return key
end

-- Scoate o creatură oriunde s-ar afla. Folosit la vânzare.
function Inventory.remove(profile: Profile, uid: string): CreatureRecord?
	local key = Inventory.findPedestal(profile, uid)
	if key then
		return Inventory.takeFromPedestal(profile, key)
	end
	local index = Inventory.findCellar(profile, uid)
	if index then
		return table.remove(profile.cellar, index)
	end
	return nil
end

return Inventory
