--!strict
-- Evenimente meteo pe server. Șansele sunt pe tick (vezi `tickSeconds`).

export type WeatherEvent = {
	id: string,
	mutation: string,
	durationSeconds: number,
	plantChancePerTick: number, -- pentru fiecare plantă în creștere
	creatureChancePerTick: number, -- pentru fiecare creatură expusă
	growthSpeed: number, -- multiplicator de creștere cât ține evenimentul
	phase: "Any" | "Day" | "Night",
	scheduleWeight: number, -- 0 = nu apare singur, doar cumpărat
}

local list: { WeatherEvent } = {
	{
		id = "Rain",
		mutation = "Wet",
		durationSeconds = 90,
		plantChancePerTick = 0.06,
		creatureChancePerTick = 0.01,
		growthSpeed = 1.5,
		phase = "Day",
		scheduleWeight = 60,
	},
	{
		id = "Hail",
		mutation = "Hail",
		durationSeconds = 60,
		plantChancePerTick = 0.05,
		creatureChancePerTick = 0.008,
		growthSpeed = 1,
		phase = "Any",
		scheduleWeight = 25,
	},
	{
		id = "FrostNight",
		mutation = "Frozen",
		durationSeconds = 120,
		plantChancePerTick = 0.04,
		creatureChancePerTick = 0.006,
		growthSpeed = 1,
		phase = "Night",
		scheduleWeight = 20,
	},
	{
		id = "GoldHarvest",
		mutation = "Golden",
		durationSeconds = 60,
		plantChancePerTick = 0.02,
		creatureChancePerTick = 0.003,
		growthSpeed = 1,
		phase = "Day",
		scheduleWeight = 5,
	},
	{
		id = "BunicaAngry",
		mutation = "Papucita",
		durationSeconds = 120,
		plantChancePerTick = 0.05,
		creatureChancePerTick = 0.008,
		growthSpeed = 1.5,
		phase = "Any",
		scheduleWeight = 0, -- doar în evenimentul de sâmbătă
	},
	{
		id = "Rainbow",
		mutation = "Rainbow",
		durationSeconds = 45,
		plantChancePerTick = 0.02,
		creatureChancePerTick = 0.003,
		growthSpeed = 1,
		phase = "Any",
		scheduleWeight = 0,
	},
}

local byId: { [string]: WeatherEvent } = {}
for _, event in list do
	byId[event.id] = table.freeze(event)
end

return table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
	tickSeconds = 5,
	minGapSeconds = 180, -- pauză minimă între două evenimente programate
	maxGapSeconds = 420,
})
