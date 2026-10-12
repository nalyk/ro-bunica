--!strict
-- Aduce un profil încărcat la schema curentă: completează câmpurile lipsă și aplică migrările.

local DataTemplate = require(script.Parent.Parent.Config.DataTemplate)

local Migrations = {}

-- Pași de migrare: MIGRATIONS[n] duce profilul de la versiunea n la n + 1.
local MIGRATIONS: { [number]: (any) -> () } = {}

-- Completează recursiv cheile lipsă din șablon. Nu suprascrie valori existente.
-- Tabelele-dicționar goale din șablon (seeds, beds…) nu impun chei.
local function fill(target: any, template: any)
	for key, value in template do
		if target[key] == nil then
			target[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil then
			fill(target[key], value)
		end
	end
end

function Migrations.reconcile(profile: any): DataTemplate.Profile
	local version = profile.version or 0
	while version < DataTemplate.VERSION do
		local step = MIGRATIONS[version]
		if step then
			step(profile)
		end
		version += 1
	end
	fill(profile, DataTemplate.new())
	profile.version = DataTemplate.VERSION
	return profile
end

return Migrations
