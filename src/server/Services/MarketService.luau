--!strict
-- Bazarul (Domain/Market): pui creaturi din beci pe taraba ta, cu preț; ceilalți cumpără cu lei. Creaturile
-- puse la vânzare apar pe tarabele din bazar, cu prețul deasupra. Duminica (UTC) bazarul e mare: 12 tarabe și
-- negustori NPC care cumpără creaturile la preț cinstit.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Market = require(Shared.Domain.Market)
local Economy = require(Shared.Domain.Economy)
local VillageLayout = require(Shared.Domain.VillageLayout)
local RateLimiter = require(Shared.Domain.RateLimiter)
local CreatureBuilder = require(Shared.Visual.CreatureBuilder)
local Actors = require(script.Parent.Parent.Actors)
local PlotService = require(script.Parent.PlotService)
local EconomyService = require(script.Parent.EconomyService)
local StateService = require(script.Parent.StateService)
local DataService = require(script.Parent.DataService)
local Messenger = require(script.Parent.Messenger)
local RegionPolicyService = require(script.Parent.RegionPolicyService)
local Analytics = require(script.Parent.Parent.Analytics)

type Owner = PlotService.Owner

local MarketService = {}

MarketService.REACH = 45 -- de cât de aproape de bazar poți vinde și cumpăra
local NPC_EVERY = 60
local market = Market.new(Market.stallsFor(false))
local limiter = RateLimiter.new(6, 2)
local bazaar = VillageLayout.build().sites.bazar
local display: Folder

local function sunday(): boolean
	return os.date("!*t").wday == 1
end

local function ownerById(id: number): Owner?
	for _, owner in PlotService.owners() do
		if owner.userId == id then
			return owner
		end
	end
	return nil
end

local function near(owner: Owner): boolean
	local root = owner.actor and Actors.root(owner.actor)
	return root ~= nil
		and Vector3.new(root.Position.X - bazaar.X, 0, root.Position.Z - bazaar.Z).Magnitude
			<= MarketService.REACH
end

-- Taraba `i`: cele 8 din bazar (SiteBuilder) și, duminica, încă 4 alături
local function stallCFrame(i: number): CFrame
	local row, col = (i - 1) // 4, (i - 1) % 4
	if i <= 8 then
		return bazaar * CFrame.new(-15 + col * 10, 3.6, -6 + row * 14)
	end
	return bazaar * CFrame.new(-15 + col * 10, 3.6, 22)
end

-- Ce se vede pe tarabe și ce află clienții
local function snapshot(): { [string]: any }
	local list = {}
	for id, listing in market.listings do
		local seller = ownerById(listing.seller)
		table.insert(list, {
			id = id,
			seller = listing.seller,
			sellerName = seller and seller.name or "",
			creature = listing.record.id,
			size = listing.record.size,
			mutation = listing.record.mutation,
			price = listing.price,
			stall = listing.stall,
		})
	end
	return { listings = list, stalls = market.stalls, sunday = sunday() }
end

-- Doar când se schimbă ceva: tarabele se refac și toți clienții primesc lista
local function publish()
	display:ClearAllChildren()
	local list = {}
	local perStall: { [number]: number } = {}
	for id, listing in market.listings do
		local seller = ownerById(listing.seller)
		table.insert(list, {
			id = id,
			seller = listing.seller,
			sellerName = seller and seller.name or "",
			creature = listing.record.id,
			size = listing.record.size,
			mutation = listing.record.mutation,
			price = listing.price,
			stall = listing.stall,
		})
		-- creatura, mică, pe masa tarabei
		local slot = perStall[listing.stall] or 0
		perStall[listing.stall] = slot + 1
		local ok, model = pcall(
			CreatureBuilder.build,
			{ id = listing.record.id, size = "Normal", mutation = listing.record.mutation },
			stallCFrame(listing.stall) * CFrame.new(-2.4 + slot * 1.6, 0, 0)
		)
		if ok and model then
			model:ScaleTo(0.4)
			model:SetAttribute("Showcase", true)
			local primary = model.PrimaryPart
			if primary then
				local gui = Instance.new("BillboardGui")
				gui.Size = UDim2.fromOffset(90, 24)
				gui.StudsOffset = Vector3.new(0, 2, 0)
				gui.MaxDistance = 60
				gui.Adornee = primary
				gui.Parent = model
				local label = Instance.new("TextLabel")
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundTransparency = 1
				label.TextScaled = true
				label.Font = Enum.Font.FredokaOne
				label.TextColor3 = Color3.fromRGB(255, 220, 90)
				label.TextStrokeTransparency = 0.3
				label.Text = Economy.formatShort(listing.price) .. " lei"
				label.Parent = gui
			end
			model.Parent = display
		end
	end
	Net.get("Market"):FireAllClients({ listings = list, stalls = market.stalls, sunday = sunday() })
end

function MarketService.market(): Market.Market
	return market
end

function MarketService.list(owner: Owner, uid: string, price: number): (string?, string?)
	if not RegionPolicyService.tradingAllowed(owner) then
		Messenger.notify(owner.player, "market.Policy")
		return nil, "Policy"
	end
	if not near(owner) then
		return nil, "Far"
	end
	local id, reason = Market.list(market, owner.userId, owner.profile :: any, uid, math.floor(price))
	if id then
		StateService.markDirty(owner.player)
		publish()
	elseif owner.player then
		Messenger.notify(owner.player, "market." .. tostring(reason))
	end
	return id, reason
end

function MarketService.unlist(owner: Owner, id: string): boolean
	local ok = Market.unlist(market, owner.userId, owner.profile :: any, id)
	if ok then
		StateService.markDirty(owner.player)
		publish()
	end
	return ok
end

function MarketService.buy(owner: Owner, id: string): (boolean, string?)
	local listing = market.listings[id]
	local seller = listing and ownerById(listing.seller)
	if not listing or not seller then
		return false, "Gone"
	end
	if not RegionPolicyService.tradingAllowed(owner) then
		Messenger.notify(owner.player, "market.Policy")
		return false, "Policy"
	end
	-- leii merg la vânzător: nu dinspre o regiune cu prețuri mai mici (Managed Pricing, arbitraj)
	if not RegionPolicyService.canGive(owner, seller) then
		Messenger.notify(owner.player, "market.PriceLevel")
		return false, "PriceLevel"
	end
	if not near(owner) then
		return false, "Far"
	end
	-- vânzătorul trebuie să aibă încă sesiunea pe acest server (altfel profilul lui nu se mai salvează aici)
	if seller.player and DataService.get(seller.player) == nil then
		return false, "Gone"
	end
	local ok, reason = Market.buy(market, seller.profile :: any, owner.profile :: any, owner.userId, id)
	if ok then
		Analytics.sink(owner.player, owner.profile, listing.price, "Market", listing.record.id)
		Analytics.source(seller.player, seller.profile, listing.price, "Market")
		-- leii s-au mutat în Market.buy; addLei(0) doar reîmprospătează clasamentul și insignele
		EconomyService.addLei(owner, 0)
		EconomyService.addLei(seller, 0)
		StateService.markDirty(owner.player)
		StateService.markDirty(seller.player)
		if seller.player then
			Messenger.notify(
				seller.player,
				"market.sold",
				{ Messenger.key("creature." .. listing.record.id), Economy.formatShort(listing.price) }
			)
		end
		publish()
	elseif owner.player then
		Messenger.notify(owner.player, "market." .. tostring(reason))
	end
	return ok, reason
end

-- Duminica: un negustor NPC cumpără o creatură pusă la un preț cinstit (cel mult de 1,5× valoarea)
function MarketService.npcBuy(): boolean
	local options = {}
	for id, listing in market.listings do
		if listing.price <= Economy.sellPrice(listing.record) * 1.5 then
			table.insert(options, id)
		end
	end
	if #options == 0 then
		return false
	end
	local id = options[math.random(1, #options)]
	local listing = market.listings[id]
	local seller = ownerById(listing.seller)
	if not seller then
		return false
	end
	local npc = { lei = listing.price, cellar = {}, cellarCapacity = 1 }
	local ok = Market.buy(market, seller.profile :: any, npc, -1, id)
	if ok then
		StateService.markDirty(seller.player)
		if seller.player then
			Messenger.notify(
				seller.player,
				"market.soldNpc",
				{ Messenger.key("creature." .. listing.record.id), Economy.formatShort(listing.price) }
			)
		end
		publish()
	end
	return ok
end

function MarketService.start()
	display = Instance.new("Folder")
	display.Name = "BazarTarabe"
	display.Parent = Workspace
	Net.get("Market").OnServerEvent:Connect(function(player, action, a, b)
		local owner = PlotService.getOwner(player)
		if not owner or not limiter:allow(player.UserId, os.clock()) then
			return
		end
		if action == "list" and typeof(a) == "string" and typeof(b) == "number" then
			MarketService.list(owner, a, b)
		elseif action == "unlist" and typeof(a) == "string" then
			MarketService.unlist(owner, a)
		elseif action == "buy" and typeof(a) == "string" then
			MarketService.buy(owner, a)
		elseif action == "refresh" then
			Net.get("Market"):FireClient(player, snapshot()) -- doar lista, fără să refacă tarabele
		end
	end)
	PlotService.onOwnerAdded(function(owner)
		-- marcajele rămase de la o cădere a serverului: creatura e acasă, nu la bazar
		for _, record in owner.profile.cellar do
			(record :: any).listed = nil
		end
	end)
	PlotService.onOwnerRemoving(function(owner)
		Market.close(market, owner.userId, owner.profile :: any)
		publish()
	end)
	task.spawn(function()
		while true do
			task.wait(NPC_EVERY)
			local stalls = market.stalls
			Market.setWanted(market, Market.stallsFor(sunday())) -- tarabele ocupate rămân până se eliberează
			if market.stalls ~= stalls then
				publish()
			end
			if sunday() then
				MarketService.npcBuy()
			end
		end
	end)
end

return MarketService
