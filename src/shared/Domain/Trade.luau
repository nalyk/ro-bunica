--!strict
-- Regulile schimbului: ofertele (creaturi din beci și lei), acceptarea și execuția atomică.
-- Orice schimbare de ofertă anulează acceptările; execuția revalidează totul și mută totul sau nimic.

local Config = script.Parent.Parent.Config
local TradeConfig = require(Config.Trade)
local Creatures = require(Config.Creatures)
local Economy = require(script.Parent.Economy)

type CreatureRecord = { uid: string, id: string, size: string, mutation: string?, soul: boolean? }
type Profile = { lei: number, cellar: { CreatureRecord }, cellarCapacity: number }

export type Offer = { uids: { string }, lei: number }
export type Session = {
	a: number,
	b: number,
	offers: { [number]: Offer },
	accepted: { [number]: boolean },
	version: number, -- crește la fiecare schimbare de ofertă
}

local Trade = {}

function Trade.new(a: number, b: number): Session
	return {
		a = a,
		b = b,
		offers = { [a] = { uids = {}, lei = 0 }, [b] = { uids = {}, lei = 0 } },
		accepted = { [a] = false, [b] = false },
		version = 0,
	}
end

function Trade.other(session: Session, who: number): number
	return if who == session.a then session.b else session.a
end

local function findInCellar(profile: Profile, uid: string): CreatureRecord?
	for _, record in profile.cellar do
		if record.uid == uid then
			return record
		end
	end
	return nil
end

-- Oferta e validă pentru profilul dat? Întoarce (true, nil) sau (false, motiv).
function Trade.checkOffer(profile: Profile, uids: { string }, lei: number): (boolean, string?)
	if #uids > TradeConfig.maxCreatures then
		return false, "TooMany"
	end
	if lei < 0 or lei ~= math.floor(lei) or lei > profile.lei then
		return false, "NotEnoughLei"
	end
	local seen: { [string]: boolean } = {}
	for _, uid in uids do
		if seen[uid] then
			return false, "Duplicate"
		end
		seen[uid] = true
		local record = findInCellar(profile, uid)
		if not record then
			return false, "NotInCellar"
		end
		local creature = Creatures.byId[record.id]
		if not creature or TradeConfig.excludedRarities[creature.rarity] then
			return false, "NotTradable"
		end
		if record.soul then
			return false, "Soul"
		end
	end
	return true, nil
end

-- Schimbă oferta unei părți. Anulează acceptările.
function Trade.setOffer(
	session: Session,
	who: number,
	profile: Profile,
	uids: { string },
	lei: number
): (boolean, string?)
	local ok, reason = Trade.checkOffer(profile, uids, lei)
	if not ok then
		return false, reason
	end
	session.offers[who] = { uids = table.clone(uids), lei = lei }
	session.accepted[session.a] = false
	session.accepted[session.b] = false
	session.version += 1
	return true, nil
end

-- O parte acceptă. Întoarce true dacă acum au acceptat amândouă.
function Trade.accept(session: Session, who: number): boolean
	session.accepted[who] = true
	return session.accepted[session.a] and session.accepted[session.b]
end

-- Valoarea unei oferte (prețul de vânzare al creaturilor + leii), ca ajutor contra păcălelilor.
function Trade.value(profile: Profile, offer: Offer): number
	local total = offer.lei
	for _, uid in offer.uids do
		local record = findInCellar(profile, uid)
		if record then
			total += Economy.sellPrice(record)
		end
	end
	return total
end

-- Totul încă se poate face? (ambele oferte valide și loc în beci de ambele părți după schimb)
function Trade.validate(session: Session, profiles: { [number]: Profile }): (boolean, string?)
	for _, who in { session.a, session.b } do
		local offer = session.offers[who]
		local ok, reason = Trade.checkOffer(profiles[who], offer.uids, offer.lei)
		if not ok then
			return false, reason
		end
	end
	for _, who in { session.a, session.b } do
		local profile = profiles[who]
		local after = #profile.cellar
			- #session.offers[who].uids
			+ #session.offers[Trade.other(session, who)].uids
		if after > profile.cellarCapacity then
			return false, "Full"
		end
	end
	return true, nil
end

-- Execută schimbul (după validate). Întoarce creaturile primite de fiecare parte.
function Trade.execute(session: Session, profiles: { [number]: Profile }): { [number]: { CreatureRecord } }
	local taken: { [number]: { CreatureRecord } } = {}
	for _, who in { session.a, session.b } do
		local profile = profiles[who]
		local list = {}
		for _, uid in session.offers[who].uids do
			for index, record in profile.cellar do
				if record.uid == uid then
					table.insert(list, table.remove(profile.cellar, index) :: CreatureRecord)
					break
				end
			end
		end
		taken[who] = list
		profile.lei -= session.offers[who].lei
	end
	local received: { [number]: { CreatureRecord } } = {}
	for _, who in { session.a, session.b } do
		local from = Trade.other(session, who)
		local profile = profiles[who]
		for _, record in taken[from] do
			table.insert(profile.cellar, record)
		end
		profile.lei += session.offers[from].lei
		received[who] = taken[from]
	end
	return received
end

return Trade
