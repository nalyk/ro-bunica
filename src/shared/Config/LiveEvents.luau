--!strict
-- Evenimente săptămânale (ora UTC). „Bunica se supără” are loc cu o oră înaintea update-ului de sâmbătă.

export type LiveEvent = {
	id: string,
	weekday: number, -- 0 = duminică … 6 = sâmbătă (UTC)
	startHourUtc: number,
	durationMinutes: number,
	weather: string, -- vremea exclusivă, repornită cât ține evenimentul
	weatherEverySeconds: number,
	slipperRainEverySeconds: number, -- papuci din cer peste hoții care cară creaturi
	exclusives: { string }, -- semințe exclusive, una pe săptămână, prin rotație
}

local list: { LiveEvent } = {
	{
		id = "BunicaSeSupara",
		weekday = 6,
		startHourUtc = 16,
		durationMinutes = 60,
		weather = "BunicaAngry",
		weatherEverySeconds = 300,
		slipperRainEverySeconds = 12,
		exclusives = { "Papucel", "Martisorel" },
	},
}

local byId: { [string]: LiveEvent } = {}
for _, event in list do
	byId[event.id] = table.freeze(event)
end

return table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
	updateHourUtc = 17, -- update-ul săptămânal (sâmbătă), după eveniment
})
