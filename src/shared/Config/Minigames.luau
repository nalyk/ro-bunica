--!strict
-- Mini-jocurile satului (docs/RESEARCH_SAT_VIU.md §5): fiecare la locul lui, rotite de ceasul satului sau
-- pornite din panoul „Mini-jocuri”. Toți participanții primesc ceva; podiumul primește în plus.
-- `ages`: pentru cine e gândit (🟢 mici, 🔵 7–10, 🟣 11+).

export type Minigame = {
	id: string,
	minPlayers: number,
	maxPlayers: number,
	durationSeconds: number,
	site: string,
	ages: string,
	rewards: { participation: number, placements: { number } },
	teams: boolean?, -- pe echipe: toată echipa câștigătoare ia bonusul de câștig
}

local function rewards(participation: number, a: number, b: number, c: number)
	return table.freeze({ participation = participation, placements = table.freeze({ a, b, c }) })
end

local list: { Minigame } = {
	{
		id = "Cocos",
		minPlayers = 2,
		maxPlayers = 8,
		durationSeconds = 60,
		site = "centru",
		ages = "🟢🔵",
		rewards = rewards(40, 80, 50, 30),
	},
	{
		id = "Sotron",
		minPlayers = 1,
		maxPlayers = 1,
		durationSeconds = 45,
		site = "magazin",
		ages = "🟢🔵",
		rewards = rewards(30, 50, 0, 0),
	},
	{
		id = "Oua",
		minPlayers = 2,
		maxPlayers = 2,
		durationSeconds = 30,
		site = "bucatarie",
		ages = "🟢🔵🟣",
		rewards = rewards(30, 60, 0, 0),
	},
	{
		id = "Oina",
		minPlayers = 4,
		maxPlayers = 8,
		durationSeconds = 180,
		site = "terenScoala",
		ages = "🔵🟣",
		rewards = rewards(60, 120, 0, 0),
		teams = true,
	},
	{
		id = "Ascunselea",
		minPlayers = 3,
		maxPlayers = 8,
		durationSeconds = 120,
		site = "lanPorumb",
		ages = "🟢🔵",
		rewards = rewards(50, 90, 60, 40),
	},
	{
		id = "Pacala",
		minPlayers = 3,
		maxPlayers = 8,
		durationSeconds = 150,
		site = "claie",
		ages = "🔵🟣",
		rewards = rewards(50, 100, 60, 40),
	},
	{
		id = "Roaba",
		minPlayers = 2,
		maxPlayers = 8,
		durationSeconds = 90,
		site = "biserica",
		ages = "🔵🟣",
		rewards = rewards(50, 100, 60, 40),
	},
	{
		id = "Moara",
		minPlayers = 1,
		maxPlayers = 8,
		durationSeconds = 120,
		site = "moara",
		ages = "🔵🟣",
		rewards = rewards(40, 90, 60, 40),
	},
	{
		id = "Struguri",
		minPlayers = 2,
		maxPlayers = 4,
		durationSeconds = 60,
		site = "via",
		ages = "🟢🔵🟣",
		rewards = rewards(40, 80, 50, 30),
	},
	{
		id = "Discoteca",
		minPlayers = 2,
		maxPlayers = 8,
		durationSeconds = 60,
		site = "discoteca",
		ages = "🟢🔵🟣",
		rewards = rewards(40, 80, 50, 30),
	},
	{
		id = "Placinte",
		minPlayers = 2,
		maxPlayers = 4,
		durationSeconds = 120,
		site = "bucatarie",
		ages = "🟢🔵🟣",
		rewards = rewards(60, 0, 0, 0),
	},
	{
		id = "Ostasi",
		minPlayers = 4,
		maxPlayers = 8,
		durationSeconds = 120,
		site = "terenScoala",
		ages = "🔵🟣",
		rewards = rewards(60, 120, 0, 0),
		teams = true,
	},
}

local byId: { [string]: Minigame } = {}
for _, def in list do
	byId[def.id] = def
end

return table.freeze({
	list = list,
	byId = byId,
	enrollSeconds = 20, -- înscrierea la loc, după anunț
	enrollDistance = 40, -- cât de aproape de loc trebuie să fii ca să intri
	countdown = 3,
	cheerStep = 0.05, -- fantomele: +5% pe încurajare
	cheerMax = 0.25,
})
