--!strict
-- Schema profilului salvat. Orice câmp nou primește aici o valoare implicită.

local Economy = require(script.Parent.Economy)

export type CreatureRecord = {
	uid: string,
	id: string,
	size: string,
	mutation: string?,
}

export type PlantRecord = {
	seedId: string,
	size: string,
	mutation: string?,
	grown: number, -- secunde de creștere acumulate
}

export type Profile = {
	version: number,
	lei: number,
	seeds: { [string]: number }, -- inventar de semințe după id
	beds: { [string]: PlantRecord }, -- cheie = index strat ca string ("1".."10")
	pedestals: { [string]: CreatureRecord }, -- cheie = index piedestal ca string
	cellar: { CreatureRecord },
	bedCount: number,
	pedestalCount: number,
	cellarCapacity: number,
	upgrades: { [string]: number },
	playSeconds: number, -- total timp jucat, pentru protecția jucătorilor noi
	lastSeen: number, -- os.time() la ultima salvare, pentru venitul offline
	tutorialDone: boolean, -- sămânța de start a fost dată
	tutorialThiefDone: boolean, -- hoțul din primul minut a fost prins
	stats: { steals: number, defends: number, hatched: number },
	uidCounter: number,
	passes: { [string]: boolean }, -- permisele Robux deja aplicate (efectele permanente, o singură dată)
	receipts: { string }, -- PurchaseId-urile procesate (anti-dublare la ProcessReceipt)
	funnel: { [string]: boolean }, -- pașii din funnel-ul primelor minute deja măsurați
	daily: { lastDay: number, streak: number }, -- recompensa zilnică: ultima zi UTC luată și seria
}

local DataTemplate = {}

DataTemplate.VERSION = 1

function DataTemplate.new(): Profile
	return {
		version = DataTemplate.VERSION,
		lei = Economy.startingLei,
		seeds = {},
		beds = {},
		pedestals = {},
		cellar = {},
		bedCount = Economy.startingBeds,
		pedestalCount = Economy.startingPedestals,
		cellarCapacity = Economy.startingCellar,
		upgrades = {},
		playSeconds = 0,
		lastSeen = 0,
		tutorialDone = false,
		tutorialThiefDone = false,
		stats = { steals = 0, defends = 0, hatched = 0 },
		uidCounter = 0,
		passes = {},
		receipts = {},
		funnel = {},
		daily = { lastDay = -1, streak = 0 },
	}
end

return DataTemplate
