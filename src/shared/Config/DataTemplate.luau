--!strict
-- Schema profilului salvat. Orice câmp nou primește aici o valoare implicită.

local Economy = require(script.Parent.Economy)

export type CreatureRecord = {
	uid: string,
	id: string,
	size: string,
	mutation: string?,
	soul: boolean?, -- creatură de suflet (Domain/Soul): nu se fură, nu se schimbă
	happiness: number?, -- fericirea (Domain/Care), 60 dacă lipsește
	lastPet: number?, -- ultima mângâiere (timpul serverului)
	hybrid: string?, -- hibrid: a doua creatură (Domain/Hybrid)
	hybridName: string?,
	listed: string?, -- pusă la bazar (id-ul ofertei); se șterge la intrarea în joc
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
	stats: {
		steals: number,
		defends: number,
		hatched: number,
		fish: number?, -- pești prinși (titlul „Pescarul”)
		hora: number?, -- hore dansate („Dansatoarea”)
		happenings: number?, -- întâmplări la care a ajutat („Prietenul satului”)
		minigames: number?, -- mini-jocuri terminate
		referrals: number?, -- prieteni noi aduși în sat („Gazda satului”, Domain/Referral)
		welcomed: number?, -- a venit adus de un prieten („Musafirul”)
	},
	referredBy: number?, -- cine l-a adus (UserId), o singură dată, la un jucător nou
	referralRewarded: boolean?, -- recompensa recomandării a fost dată (după 10 minute)
	title: string?, -- titlul ales (Domain/Titles)
	outfits: { [string]: boolean }, -- ținutele Bunicii cumpărate (Config/Outfits)
	outfit: string?, -- ținuta purtată
	food: { [string]: number }, -- hrana pentru creaturi (plăcinte de la Plăcintărie)
	hybrids: { [string]: boolean }, -- hibrizii descoperiți (Domain/Hybrid.key)
	codes: { [string]: boolean }, -- codurile folosite (Domain/Codes)
	uidCounter: number,
	passes: { [string]: boolean }, -- permisele Robux deja aplicate (efectele permanente, o singură dată)
	receipts: { string }, -- PurchaseId-urile procesate (anti-dublare la ProcessReceipt)
	funnel: { [string]: boolean }, -- pașii din funnel-ul primelor minute deja măsurați
	daily: { lastDay: number, streak: number }, -- recompensa zilnică: ultima zi UTC luată și seria
	familyMode: string, -- "Family" (prietenii se ajută) sau "Rival" (prietenii se pot fura)
	collection: { [string]: boolean }, -- Caietul Bunicii: intrările descoperite ("id" sau "id:mutație")
	quests: {
		day: number,
		list: { { kind: string, goal: number, progress: number, claimed: boolean } },
		bonusClaimed: boolean,
	},
	rebirths: number, -- renașteri făcute (+50% venit fiecare)
	eggs: { [string]: number }, -- ouăle pentru ciocnit (Domain/EggDuel): colecția câștigată
	records: { [string]: number }, -- recordurile personale la mini-jocuri (Șotron, Moara)
	fish: { [string]: number }, -- peștii prinși la iaz (Config/Fish): de vândut sau hrană pentru creaturi
	decor: { [string]: string }, -- decorul ogrăzii: slot → obiect (Config/Decor)
	ownedDecor: { [string]: number }, -- obiectele de decor cumpărate (câte bucăți)
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
		familyMode = "Family",
		collection = {},
		quests = { day = -1, list = {}, bonusClaimed = false },
		rebirths = 0,
		eggs = { Alb = 3 },
		records = {},
		fish = {},
		decor = {},
		ownedDecor = {},
		outfits = {},
		food = {},
		hybrids = {},
		codes = {},
	}
end

return DataTemplate
