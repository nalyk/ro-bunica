--!strict
-- Bazarul: fiecare jucător închiriază (gratuit) o tarabă și pune până la 4 creaturi din beci, cu preț între 25%
-- și 10× din valoarea de vânzare (anti-spălare). Creatura rămâne în beci, marcată `listed` (dacă serverul cade,
-- nu se pierde nimic; marcajul se șterge la intrare); cumpărarea mută leii și creatura deodată. Plecarea
-- vânzătorului golește taraba.

local Economy = require(script.Parent.Economy)

type Record = { uid: string, id: string, size: string, mutation: string?, soul: boolean?, listed: string? }
type Profile = { lei: number, cellar: { any }, cellarCapacity: number }
export type Listing = { id: string, seller: number, record: Record, price: number, stall: number }
export type Market = {
	stalls: number,
	listings: { [string]: Listing },
	stallOf: { [number]: number },
	counter: number,
}

local Market = {}

Market.PER_STALL = 4
Market.MIN = 0.25
Market.MAX = 10

function Market.new(stalls: number): Market
	return { stalls = stalls, listings = {}, stallOf = {}, counter = 0 }
end

-- Tarabe: 8 în zilele obișnuite, 12 duminica (bazarul mare)
function Market.stallsFor(sunday: boolean): number
	return if sunday then 12 else 8
end

function Market.priceRange(record: Record): (number, number)
	local value = Economy.sellPrice(record)
	return math.ceil(value * Market.MIN), math.floor(value * Market.MAX)
end

local function countFor(market: Market, seller: number): number
	local n = 0
	for _, listing in market.listings do
		if listing.seller == seller then
			n += 1
		end
	end
	return n
end

local function freeStall(market: Market): number?
	local used = {}
	for _, stall in market.stallOf do
		used[stall] = true
	end
	for i = 1, market.stalls do
		if not used[i] then
			return i
		end
	end
	return nil
end

-- Pune `uid` din beci la vânzare. Întoarce id-ul ofertei sau (nil, motiv).
function Market.list(
	market: Market,
	seller: number,
	profile: Profile,
	uid: string,
	price: number
): (string?, string?)
	local index, record = nil, nil
	for i, r in profile.cellar do
		if r.uid == uid then
			index, record = i, r
			break
		end
	end
	if not index or not record then
		return nil, "Missing"
	end
	if record.soul then
		return nil, "Soul"
	end
	if record.listed then
		return nil, "Listed"
	end
	local low, high = Market.priceRange(record)
	if price < low or price > high or price ~= math.floor(price) then
		return nil, "Price"
	end
	if countFor(market, seller) >= Market.PER_STALL then
		return nil, "StallFull"
	end
	local stall: number? = market.stallOf[seller]
	if not stall then
		stall = freeStall(market)
		if not stall then
			return nil, "NoStall"
		end
		market.stallOf[seller] = stall
	end
	market.counter += 1
	local id = tostring(market.counter)
	record.listed = id
	market.listings[id] =
		{ id = id, seller = seller, record = record, price = price, stall = stall :: number }
	return id, nil
end

-- Retrage o ofertă: creatura se întoarce în beci (dacă e loc)
function Market.unlist(market: Market, seller: number, _profile: Profile, id: string): boolean
	local listing = market.listings[id]
	if not listing or listing.seller ~= seller then
		return false
	end
	market.listings[id] = nil
	listing.record.listed = nil
	if countFor(market, seller) == 0 then
		market.stallOf[seller] = nil
	end
	return true
end

-- Cumpără oferta: totul sau nimic
function Market.buy(
	market: Market,
	sellerProfile: Profile,
	buyer: Profile,
	buyerId: number,
	id: string
): (boolean, string?)
	local listing = market.listings[id]
	if not listing then
		return false, "Gone"
	end
	if listing.seller == buyerId then
		return false, "Own"
	end
	if buyer.lei < listing.price then
		return false, "NotEnoughLei"
	end
	if #buyer.cellar >= buyer.cellarCapacity then
		return false, "CellarFull"
	end
	-- creatura e încă în beciul vânzătorului (marcată): o mutăm de acolo
	local index = nil
	for i, r in sellerProfile.cellar do
		if r.uid == listing.record.uid then
			index = i
			break
		end
	end
	if not index then
		market.listings[id] = nil
		return false, "Gone"
	end
	market.listings[id] = nil
	local record = table.remove(sellerProfile.cellar, index) :: Record
	record.listed = nil
	buyer.lei -= listing.price
	sellerProfile.lei += listing.price
	table.insert(buyer.cellar, record)
	if countFor(market, listing.seller) == 0 then
		market.stallOf[listing.seller] = nil
	end
	return true, nil
end

-- Vânzătorul a plecat: taraba se golește, creaturile se întorc în beciul lui
function Market.close(market: Market, seller: number, profile: Profile)
	for id, listing in market.listings do
		if listing.seller == seller then
			market.listings[id] = nil
		end
	end
	for _, record in profile.cellar do
		record.listed = nil
	end
	market.stallOf[seller] = nil
end

return Market
