--!strict
-- Peștii (și ce mai iese) din iazul satului: pentru colecție, de vândut sau hrană pentru creaturi (îngrijirea).
-- `weight`: șansa de bază; `rare`: ploaia îi aduce mai des; `seasons`: anotimpurile în care mușcă (nil = oricând).

export type Fish = {
	id: string,
	weight: number,
	sell: number,
	rare: boolean?,
	seasons: { string }?,
	egg: boolean?, -- „oul de creatură”: dă o sămânță rară, nu un pește
}

local list: { Fish } = {
	{ id = "crapRacheta", weight = 30, sell = 40 },
	{ id = "carasVesel", weight = 26, sell = 30 },
	{ id = "cizmaVeche", weight = 16, sell = 5 },
	{ id = "broascaDJ", weight = 9, sell = 120, rare = true, seasons = { "Primavara", "Vara", "Toamna" } },
	{ id = "stiucaNinja", weight = 8, sell = 160, rare = true },
	{ id = "somnulSomnoros", weight = 5, sell = 300, rare = true, seasons = { "Vara", "Toamna", "Iarna" } },
	{ id = "carasAuriu", weight = 1.5, sell = 900, rare = true },
	{ id = "ouCreatura", weight = 1, sell = 0, rare = true, egg = true },
}

local byId: { [string]: Fish } = {}
for _, fish in list do
	byId[fish.id] = fish
end

return table.freeze({
	list = list,
	byId = byId,
	rainBoost = 2, -- ploaia dublează șansele peștilor rari
	biteMin = 2, -- secundele până la tremurul plutei
	biteMax = 8,
	biteWindow = 2.5, -- cât ai să începi să tragi după tremur
	castDistance = 46, -- cât de aproape de iaz trebuie să fii
	reelStep = 0.1, -- pasul simulării tensiunii (clientul trimite apăsările pe pași)
	maxSteps = 400,
})
