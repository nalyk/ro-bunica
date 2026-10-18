--!strict
-- Întâmplările satului (docs/RESEARCH_SAT_VIU.md §4): una la 6–8 minute, anunțată cu 30 s înainte, 60–120 s,
-- cu răsplată pentru participare. Rotite (niciuna de două ori la rând), cel mult una activă, niciuna pe Robux.
-- `location` e o cheie din Config/Village.sites.

export type Happening = {
	id: string,
	phase: "Day" | "Night" | "Any",
	weight: number,
	warnSeconds: number,
	durationSeconds: number,
	minPlayers: number,
	cooldownSeconds: number,
	location: string,
}

local list: { Happening } = {
	{
		id = "Gaste",
		phase = "Day",
		weight = 3,
		warnSeconds = 30,
		durationSeconds = 90,
		minPlayers = 1,
		cooldownSeconds = 900,
		location = "centru",
	},
	{
		id = "Cirese",
		phase = "Day",
		weight = 3,
		warnSeconds = 30,
		durationSeconds = 75,
		minPlayers = 1,
		cooldownSeconds = 900,
		location = "livada",
	},
	{
		id = "Negustor",
		phase = "Day",
		weight = 2,
		warnSeconds = 30,
		durationSeconds = 90,
		minPlayers = 1,
		cooldownSeconds = 1200,
		location = "centru",
	},
	{
		id = "Nunta",
		phase = "Day",
		weight = 2,
		warnSeconds = 30,
		durationSeconds = 100,
		minPlayers = 1,
		cooldownSeconds = 1200,
		location = "centru",
	},
	{
		id = "Lupi",
		phase = "Night",
		weight = 3,
		warnSeconds = 30,
		durationSeconds = 100,
		minPlayers = 1,
		cooldownSeconds = 900,
		location = "stana",
	},
	{
		id = "Ceata",
		phase = "Night",
		weight = 2,
		warnSeconds = 20,
		durationSeconds = 60,
		minPlayers = 2,
		cooldownSeconds = 900,
		location = "codru",
	},
	{
		id = "MumaPadurii",
		phase = "Night",
		weight = 1,
		warnSeconds = 30,
		durationSeconds = 120,
		minPlayers = 1,
		cooldownSeconds = 2400,
		location = "codru",
	},
	-- trenul nu intră în tragerea la sorți: vine când a trecut o oră de la ultimul (VillageClock.next)
	{
		id = "Tren",
		phase = "Any",
		weight = 0,
		warnSeconds = 30,
		durationSeconds = 90,
		minPlayers = 1,
		cooldownSeconds = 3600,
		location = "gara",
	},
}

local byId: { [string]: Happening } = {}
for _, def in list do
	byId[def.id] = def
end

return table.freeze({
	list = list,
	byId = byId,
	minGap = 360, -- între două întâmplări: 6–8 minute
	maxGap = 480,
	participation = 40, -- lei pentru oricine a participat
	podium = table.freeze({ 60, 35, 20 }), -- în plus pentru locurile 1–3
})
