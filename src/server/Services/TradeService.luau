--!strict
-- Schimburile între jucători (Domain/Trade): cerere → acceptare → fereastra de schimb, în care fiecare oferă
-- creaturi din beci și lei. Orice schimbare de ofertă anulează acceptările; după ce acceptă amândoi urmează
-- o numărătoare de 3 s, apoi serverul revalidează și mută totul sau nimic. Creaturile primite NU intră în Caiet:
-- caietul ține ce ai crescut sau furat tu (altfel conturi noi ar „cultiva” recompensele de descoperire).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local TradeConfig = require(Shared.Config.Trade)
local Trade = require(Shared.Domain.Trade)
local RateLimiter = require(Shared.Domain.RateLimiter)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)
local EconomyService = require(script.Parent.EconomyService)
local Messenger = require(script.Parent.Messenger)
local RegionPolicyService = require(script.Parent.RegionPolicyService)
local Analytics = require(script.Parent.Parent.Analytics)

type Owner = PlotService.Owner
-- Părțile sunt proprietari de ogrăzi (jucători; în teste, boți cu ogradă), cheia = userId
type Live = { session: Trade.Session, parties: { [number]: Owner }, confirmAt: number?, done: boolean }

local TradeService = {}

local limiter = RateLimiter.new(12, 4)
local lastRequest: { [Owner]: number } = {}
local requests: { [Owner]: { [Owner]: number } } = {} -- ținta → cine a cerut → până când
local trades: { [Owner]: Live } = {}

local function present(owner: Owner): boolean
	return not owner.removing and owner.plot.owner == owner
end

local function fire(owner: Owner, kind: string, data: { [string]: any })
	if owner.player and owner.player.Parent == Players then
		Net.get("TradeUpdate"):FireClient(owner.player, kind, data)
	end
end

-- Ambele părți sunt încă pe server, cu ograda lor?
local function owners(live: Live): { [number]: Owner }?
	for _, owner in live.parties do
		if not present(owner) then
			return nil
		end
	end
	return live.parties
end

local function profilesOf(list: { [number]: Owner }): { [number]: any }
	local result = {}
	for id, owner in list do
		result[id] = owner.profile
	end
	return result
end

-- Ce vede fiecare parte: ofertele (cu creaturile), valorile, acceptările și numărătoarea.
local function send(live: Live)
	local list = owners(live)
	if not list then
		return
	end
	local session = live.session
	local views = {}
	for id, owner in list do
		local offer = session.offers[id]
		local records = {}
		for _, uid in offer.uids do
			for _, record in owner.profile.cellar do
				if record.uid == uid then
					table.insert(records, record)
				end
			end
		end
		views[id] = {
			records = records,
			lei = offer.lei,
			value = Trade.value(owner.profile, offer),
			accepted = session.accepted[id],
		}
	end
	for id, owner in live.parties do
		local other = Trade.other(session, id)
		fire(owner, "state", {
			partner = live.parties[other].name,
			mine = views[id],
			theirs = views[other],
			confirmAt = live.confirmAt,
		})
	end
end

local function close(live: Live, reason: string)
	for _, owner in live.parties do
		if trades[owner] == live then
			trades[owner] = nil
			fire(owner, "closed", { reason = reason })
		end
	end
end

local function execute(live: Live, version: number)
	-- o singură execuție pe schimb: `done` se pune înainte de orice mutare
	if live.done or live.session.version ~= version or not live.confirmAt then
		return
	end
	live.done = true
	live.confirmAt = nil
	local list = owners(live)
	if not list then
		close(live, "Left")
		return
	end
	local profiles = profilesOf(list)
	local ok, reason = Trade.validate(live.session, profiles)
	if not ok then
		close(live, tostring(reason))
		return
	end
	local session = live.session
	local leiBefore = {}
	for id, profile in profiles do
		leiBefore[id] = profile.lei
	end
	Trade.execute(session, profiles)
	for id, owner in list do
		-- leii s-au mutat direct în profil; addLei(0) sincronizează clasamentul și starea
		EconomyService.addLei(owner, 0)
		local delta = owner.profile.lei - leiBefore[id]
		if delta > 0 then
			Analytics.source(owner.player, owner.profile, delta, "Trade")
		elseif delta < 0 then
			Analytics.sink(owner.player, owner.profile, -delta, "Trade")
		end
		Analytics.event(owner.player, "Trade")
		StateService.markDirty(owner.player)
	end
	close(live, "Done")
end

local function startTrade(a: Owner, b: Owner)
	local session = Trade.new(a.userId, b.userId)
	local live: Live =
		{ session = session, parties = { [a.userId] = a, [b.userId] = b }, confirmAt = nil, done = false }
	trades[a] = live
	trades[b] = live
	send(live)
end

-- Cererea de schimb de la `from` către `to`.
function TradeService.request(from: Owner, to: Owner): boolean
	if from == to or not present(from) or not present(to) then
		return false
	end
	-- unde schimbul de lucruri plătite nu e permis (PolicyService), nu se schimbă deloc
	if not RegionPolicyService.tradingAllowed(from) then
		Messenger.notify(from.player, "notify.TradePolicy")
		return false
	end
	if not RegionPolicyService.tradingAllowed(to) then
		Messenger.notify(from.player, "notify.TradePolicyOther", { to.name })
		return false
	end
	if trades[from] or trades[to] then
		Messenger.notify(from.player, "notify.TradeBusy")
		return false
	end
	local now = os.clock()
	if lastRequest[from] and now - lastRequest[from] < TradeConfig.requestCooldown then
		Messenger.notify(from.player, "notify.TradeWait")
		return false
	end
	lastRequest[from] = now
	-- cerere în ambele sensuri: e un „da”
	local mine = requests[from]
	if mine and mine[to] and mine[to] > now then
		mine[to] = nil
		startTrade(to, from)
		return true
	end
	requests[to] = requests[to] or {}
	requests[to][from] = now + TradeConfig.requestSeconds
	fire(to, "request", { from = from.userId, name = from.name })
	Messenger.notify(from.player, "notify.TradeSent", { to.name })
	return true
end

-- Răspunsul lui `to` la cererea lui `from`.
function TradeService.respond(to: Owner, from: Owner, yes: boolean): boolean
	local pending = requests[to]
	local expires = pending and pending[from]
	if not expires or expires < os.clock() then
		return false
	end
	(pending :: any)[from] = nil
	if not yes then
		Messenger.notify(from.player, "notify.TradeDeclined", { to.name })
		return false
	end
	if trades[from] or trades[to] or not present(from) or not present(to) then
		Messenger.notify(to.player, "notify.TradeBusy")
		return false
	end
	if not (RegionPolicyService.tradingAllowed(from) and RegionPolicyService.tradingAllowed(to)) then
		Messenger.notify(to.player, "notify.TradePolicy")
		return false
	end
	startTrade(from, to)
	return true
end

function TradeService.offer(owner: Owner, uids: { string }, lei: number): boolean
	local live = trades[owner]
	if not live then
		return false
	end
	local ok, reason = Trade.setOffer(live.session, owner.userId, owner.profile, uids, lei)
	if not ok then
		Messenger.notify(owner.player, "notify.Trade" .. tostring(reason))
		return false
	end
	live.confirmAt = nil
	send(live)
	return true
end

function TradeService.accept(owner: Owner): boolean
	local live = trades[owner]
	-- deja acceptat sau numărătoarea pornită: un „Accept” în plus nu programează a doua execuție
	if not live or live.done or live.confirmAt or live.session.accepted[owner.userId] then
		return false
	end
	local both = Trade.accept(live.session, owner.userId)
	if both then
		local list = owners(live)
		local ok, reason: string? = false, "Left"
		if list then
			ok, reason = Trade.validate(live.session, profilesOf(list))
		end
		if not ok then
			-- nu se poate (de exemplu beciul plin): acceptările cad și amândoi află de ce
			live.session.accepted[live.session.a] = false
			live.session.accepted[live.session.b] = false
			for _, party in live.parties do
				Messenger.notify(party.player, "notify.Trade" .. tostring(reason))
			end
			send(live)
			return false
		end
		live.confirmAt = Workspace:GetServerTimeNow() + TradeConfig.confirmSeconds
		local version = live.session.version
		task.delay(TradeConfig.confirmSeconds, execute, live, version)
	end
	send(live)
	return true
end

function TradeService.cancel(owner: Owner)
	local live = trades[owner]
	if live then
		close(live, "Cancelled")
	end
end

function TradeService.isTrading(owner: Owner): boolean
	return trades[owner] ~= nil
end

-- Pentru teste: momentul la care se va face schimbul (după ce au acceptat amândoi), dacă e programat.
function TradeService.confirmAt(owner: Owner): number?
	local live = trades[owner]
	return if live then live.confirmAt else nil
end

local function parseUids(value: unknown): { string }?
	if typeof(value) ~= "table" then
		return nil
	end
	local list = {}
	for index, uid in value :: { any } do
		if typeof(index) ~= "number" or typeof(uid) ~= "string" or #list >= TradeConfig.maxCreatures then
			return nil
		end
		table.insert(list, uid)
	end
	return list
end

-- Partea cu acest userId (jucător sau, în teste, bot cu ogradă). O cerere către cineva fără client rămâne
-- fără răspuns, iar un răspuns cere o cerere reală de la acea parte, deci un client nu poate forța nimic.
local function ownerById(userId: unknown): Owner?
	if typeof(userId) ~= "number" then
		return nil
	end
	for _, owner in PlotService.owners() do
		if owner.userId == userId and (owner.kind == "Player" or owner.actor ~= nil) then
			return owner
		end
	end
	return nil
end

local function onRequest(player: Player, action: unknown, a: unknown, b: unknown)
	local owner = PlotService.getOwner(player)
	if not owner or not limiter:allow(player.UserId, os.clock()) then
		return
	end
	if action == "request" then
		local target = ownerById(a)
		if target then
			TradeService.request(owner, target)
		end
	elseif action == "respond" and typeof(b) == "boolean" then
		local from = ownerById(a)
		if from then
			TradeService.respond(owner, from, b)
		end
	elseif action == "offer" and typeof(b) == "number" and b == b and b < math.huge then
		local uids = parseUids(a)
		if uids then
			TradeService.offer(owner, uids, math.floor(math.max(b, 0)))
		end
	elseif action == "accept" then
		TradeService.accept(owner)
	elseif action == "cancel" then
		TradeService.cancel(owner)
	end
end

function TradeService.start()
	Net.get("Trade").OnServerEvent:Connect(onRequest)
	PlotService.onOwnerRemoving(function(owner)
		local live = trades[owner]
		if live then
			close(live, "Left")
		end
		requests[owner] = nil
		for _, pending in requests do
			pending[owner] = nil
		end
		lastRequest[owner] = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player.UserId)
	end)
end

return TradeService
