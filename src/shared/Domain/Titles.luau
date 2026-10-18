--!strict
-- Titlurile de deasupra numelui (drumurile paralele spre statut): se câștigă din ce faci în sat, se alege unul.
-- `stat`: câmpul din statisticile jucătorului (TitleService le adună din profil).

export type Title = { id: string, stat: string, need: number }

local Titles = {}

Titles.list = {
	{ id = "hot", stat = "steals", need = 25 }, -- Hoțul satului
	{ id = "papucAur", stat = "defends", need = 50 }, -- Papucul de aur
	{ id = "pescar", stat = "fish", need = 20 }, -- Pescarul
	{ id = "dansatoare", stat = "hora", need = 15 }, -- Dansatoarea
	{ id = "colectionar", stat = "collection", need = 20 }, -- Colecționarul
	{ id = "gospodina", stat = "decor", need = 8 }, -- Gospodina
	{ id = "prieten", stat = "happenings", need = 10 }, -- Prietenul satului (ajută la întâmplări)
} :: { Title }

Titles.byId = {} :: { [string]: Title }
for _, def in Titles.list do
	Titles.byId[def.id] = def
end

function Titles.earned(stats: { [string]: number }): { string }
	local list = {}
	for _, def in Titles.list do
		if (stats[def.stat] or 0) >= def.need then
			table.insert(list, def.id)
		end
	end
	return list
end

function Titles.canUse(stats: { [string]: number }, id: string): boolean
	local def = Titles.byId[id]
	return def ~= nil and (stats[def.stat] or 0) >= def.need
end

return Titles
