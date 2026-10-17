--!strict
-- Hora: ritualul din vatra satului. 3+ jucători care dansează în cerc cheamă o vreme rară pentru server.

return table.freeze({
	center = require(script.Parent.Village).hub, -- centrul satului, pe ulicioara dintre cele două drumuri
	radius = 11,
	wellRadius = 2.5,
	minDancers = 3,
	holdSeconds = 4,
	danceSeconds = 6, -- cât ține un apăsat pe „Horă”; se reîmprospătează apăsând din nou
	cooldownSeconds = 20 * 60,
	rewards = table.freeze({
		{ value = "GoldHarvest", weight = 3 },
		{ value = "Rainbow", weight = 1 },
	}),
})
