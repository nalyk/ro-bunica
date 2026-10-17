--!strict
-- Creaturile „de suflet”: cel mult 3, marcate cu o inimă. Nu pot fi furate, schimbate sau vândute la bazar,
-- ca un copil să-și poată proteja creaturile iubite (cercetarea: pierderea definitivă îi face pe cei mici să plece).

local DataTemplate = require(script.Parent.Parent.Config.DataTemplate)

type CreatureRecord = DataTemplate.CreatureRecord
type Profile = DataTemplate.Profile

local Soul = {}

Soul.MAX = 3

local function find(profile: Profile, uid: string): CreatureRecord?
	for _, record in profile.pedestals do
		if record.uid == uid then
			return record
		end
	end
	for _, record in profile.cellar do
		if record.uid == uid then
			return record
		end
	end
	return nil
end

function Soul.count(profile: Profile): number
	local n = 0
	for _, record in profile.pedestals do
		if record.soul then
			n += 1
		end
	end
	for _, record in profile.cellar do
		if record.soul then
			n += 1
		end
	end
	return n
end

function Soul.canSet(profile: Profile, uid: string, on: boolean): (boolean, string?)
	local record = find(profile, uid)
	if not record then
		return false, "Missing"
	end
	if on and not record.soul and Soul.count(profile) >= Soul.MAX then
		return false, "Max"
	end
	return true, nil
end

function Soul.set(profile: Profile, uid: string, on: boolean): boolean
	if not Soul.canSet(profile, uid, on) then
		return false
	end
	local record = find(profile, uid) :: CreatureRecord
	record.soul = if on then true else nil
	return true
end

function Soul.isSoul(record: { soul: boolean? }?): boolean
	return record ~= nil and record.soul == true
end

return Soul
