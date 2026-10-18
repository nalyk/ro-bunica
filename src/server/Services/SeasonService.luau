--!strict
-- Calendarul sezonier (Domain/Seasons): ce sărbătoare e acum (UTC) și ce aduce ea.
-- - Mărțișor: straturile cresc cu 20% mai repede.
-- - Paște: ouă încondeiate ascunse prin sat (le aduni trecând pe lângă ele); ciocnitul dă ouă rare.
-- - Drăgaica: arunci o coroniță pe acoperiș, o dată pe zi; dacă rămâne sus, 250 de lei.
-- - Culesul: zdrobitul strugurilor e propus mai des; în lanul de porumb e ascuns un știulete roșu.
-- - Hramul satului (o zi pe lună, pe server): casă deschisă (nu se fură), decorul dă +1% venit pe obiect.
-- - Iarna: colinde la porțile vecinilor (un colac de 60 de lei de la fiecare, o dată pe zi), Capra și Ursul în
--   centru, masca de Malanca (Bunica nu te recunoaște 30 s, o dată la 5 minute).
-- Starea: GameState.Holidays ("Paste,Hram"), GameState.Season (anotimpul).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local GameState = require(Shared.GameState)
local Seasons = require(Shared.Domain.Seasons)
local Decor = require(Shared.Domain.Decor)
local Creatures = require(Shared.Config.Creatures)
local Village = require(Shared.Config.Village)
local VillageLayout = require(Shared.Domain.VillageLayout)
local RateLimiter = require(Shared.Domain.RateLimiter)
local Actors = require(script.Parent.Parent.Actors)
local Kit = require(script.Parent.Parent.Happenings.Kit)
local PlotService = require(script.Parent.PlotService)
local GardenService = require(script.Parent.GardenService)
local RaidService = require(script.Parent.RaidService)
local EconomyService = require(script.Parent.EconomyService)
local BunicaService = require(script.Parent.BunicaService)
local StateService = require(script.Parent.StateService)
local Messenger = require(script.Parent.Messenger)

type Owner = PlotService.Owner

local SeasonService = {}

SeasonService.EGGS = 16
SeasonService.CROWN_LEI = 250
SeasonService.COLAC_LEI = 60
SeasonService.MASK_SECONDS = 30
SeasonService.MASK_COOLDOWN = 300
local TICK = 1
local COB_EVERY = 1800

local forced: { string }? = nil
local active: { [string]: boolean } = {}
local serverSeed = math.random(1, 1000000)
local folder: Folder
local eggs: { BasePart } = {}
local cob: BasePart? = nil
local nextCob = 0
local maskReady: { [Actors.Actor]: number } = {}
local limiter = RateLimiter.new(4, 1)
local layout = VillageLayout.build()

local function today(): number
	return Workspace:GetServerTimeNow() // 86400
end

function SeasonService.isActive(id: string): boolean
	return active[id] == true
end

-- Pentru teste și playtest: sărbătorile impuse (nil = calendarul)
function SeasonService.force(list: { string }?)
	forced = list
	SeasonService.refresh()
end

local function seasonal(owner: Owner): { [string]: any }
	local data = (owner.profile :: any).seasonal
	if not data or data.day ~= today() then
		data = { day = today(), colinde = {}, crown = false }
		(owner.profile :: any).seasonal = data
	end
	return data
end

-- Ouăle de Paște: încondeiate, ascunse prin vale
local function spawnEgg()
	local rng = Random.new()
	local center = Village.hub
	local p = Kit.freePoint(center, 280, rng)
	local egg = Instance.new("Part")
	egg.Name = "OuDePaste"
	egg.Shape = Enum.PartType.Ball
	egg.Size = Vector3.new(1.1, 1.5, 1.1)
	egg.Color = ({ Color3.fromRGB(200, 30, 40), Color3.fromRGB(240, 200, 60), Color3.fromRGB(60, 110, 190) })[rng:NextInteger(
		1,
		3
	)]
	egg.Material = Enum.Material.SmoothPlastic
	egg.Anchored = true
	egg.CanCollide = false
	egg.CanQuery = false
	egg.Position = p + Vector3.new(0, 0.75, 0)
	egg.Parent = folder
	table.insert(eggs, egg)
end

local function clearEggs()
	for _, egg in eggs do
		egg:Destroy()
	end
	table.clear(eggs)
end

local function placeCob()
	local sites = Workspace:FindFirstChild("Village") and Workspace.Village:FindFirstChild("Sites")
	local lan = sites and sites:FindFirstChild("lanPorumb")
	local center = if lan and lan.PrimaryPart
		then lan.PrimaryPart.Position
		else layout.sites.lanPorumb.Position
	local rng = Random.new()
	local p = center + Vector3.new(rng:NextInteger(-4, 4) * 8 + 4, 0, rng:NextInteger(-4, 4) * 8 + 4)
	local part = Instance.new("Part")
	part.Name = "StiuleteRosu"
	part.Size = Vector3.new(0.7, 1.8, 0.7)
	part.Color = Color3.fromRGB(190, 30, 30)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Position = Vector3.new(p.X, Kit.groundY(p.X, p.Z) + 1, p.Z)
	part.Parent = folder
	cob = part
end

-- Capra și Ursul dansează în centru (Iarna)
local function parade(on: boolean)
	local old = folder:FindFirstChild("CapraSiUrsul")
	if old then
		old:Destroy()
	end
	if not on then
		return
	end
	local group = Instance.new("Folder")
	group.Name = "CapraSiUrsul"
	group.Parent = folder
	local hub = Village.hub
	Kit.figure(
		"Capra",
		CFrame.new(hub + Vector3.new(-8, 0, -24)),
		Color3.fromRGB(230, 50, 60),
		group,
		Color3.fromRGB(240, 230, 210)
	)
	Kit.figure(
		"Ursul",
		CFrame.new(hub + Vector3.new(8, 0, -24)),
		Color3.fromRGB(90, 60, 40),
		group,
		Color3.fromRGB(70, 46, 30)
	)
end

function SeasonService.refresh()
	local now = Workspace:GetServerTimeNow()
	local list = forced or Seasons.active(now, Seasons.hramDay(serverSeed))
	local was = table.clone(active)
	table.clear(active)
	for _, id in list do
		active[id] = true
	end
	GameState.set(GameState.Attributes.Holidays, table.concat(list, ","))
	GameState.set(GameState.Attributes.Season, Seasons.season(now))
	GardenService.seasonFactor = if active.Martisor then 1.2 else 1
	RaidService.holiday = active.Hram == true
	if was.Paste and not active.Paste then
		clearEggs()
	end
	if was.Culesul and not active.Culesul and cob then
		cob:Destroy()
		cob = nil
	end
	if (was.Iarna == true) ~= (active.Iarna == true) then
		parade(active.Iarna == true)
	end
end

-- Pentru teste
function SeasonService.eggs(): { BasePart }
	return eggs
end

function SeasonService.cob(): BasePart?
	return cob
end

local function giveEgg(owner: Owner)
	local roll = math.random()
	local egg = if roll < 0.1 then "Auriu" elseif roll < 0.4 then "Incondeiat" else "Rosu"
	owner.profile.eggs = owner.profile.eggs or {}
	owner.profile.eggs[egg] = (owner.profile.eggs[egg] or 0) + 1
	Messenger.notify(owner.player, "season.egg", { Messenger.key("egg." .. egg) })
	StateService.markDirty(owner.player)
end

-- Acțiunile de sezon ale unui jucător (sau bot)
function SeasonService.act(owner: Owner, action: string): boolean
	local root = owner.actor and Actors.root(owner.actor)
	if not root then
		return false
	end
	local data = seasonal(owner)
	if action == "crown" and active.Dragaica then
		if data.crown then
			return false
		end
		data.crown = true
		local stays = math.random() < 0.6
		if stays then
			EconomyService.addLei(owner, SeasonService.CROWN_LEI)
		end
		Messenger.notify(
			owner.player,
			if stays then "season.crownStays" else "season.crownFell",
			{ tostring(SeasonService.CROWN_LEI) }
		)
		return stays
	elseif action == "colinda" and active.Iarna then
		-- la poarta unui vecin NPC
		for _, plot in PlotService.plots do
			local npc = plot.owner
			local gate = (plot.geometry.cframe * CFrame.new(0, 0, -35)).Position
			if npc and npc.kind == "Npc" and not npc.standIn and (root.Position - gate).Magnitude <= 14 then
				if data.colinde[tostring(plot.index)] then
					Messenger.notify(owner.player, "season.colindaDone")
					return false
				end
				data.colinde[tostring(plot.index)] = true
				EconomyService.addLei(owner, SeasonService.COLAC_LEI)
				Messenger.notify(
					owner.player,
					"season.colac",
					{ npc.name, tostring(SeasonService.COLAC_LEI) }
				)
				return true
			end
		end
		Messenger.notify(owner.player, "season.colindaFar")
		return false
	elseif action == "mask" and active.Iarna then
		local actor = owner.actor :: Actors.Actor
		if os.clock() < (maskReady[actor] or 0) then
			return false
		end
		maskReady[actor] = os.clock() + SeasonService.MASK_COOLDOWN
		BunicaService.disguise(actor, SeasonService.MASK_SECONDS)
		local character = Actors.characterOf(actor)
		if character then
			character:SetAttribute("Malanca", Workspace:GetServerTimeNow() + SeasonService.MASK_SECONDS)
		end
		Messenger.notify(owner.player, "season.mask", { tostring(SeasonService.MASK_SECONDS) })
		return true
	end
	return false
end

local function tick()
	-- ouăle și știuletele: cine trece pe lângă ele le ia
	local owners = {}
	for _, owner in PlotService.owners() do
		if owner.kind == "Player" or owner.standIn then
			table.insert(owners, owner)
		end
	end
	if active.Paste then
		while #eggs < SeasonService.EGGS do
			spawnEgg()
		end
		for index = #eggs, 1, -1 do
			local egg = eggs[index]
			local finder = Kit.nearest(owners, egg.Position, 4)
			if finder then
				egg:Destroy()
				table.remove(eggs, index)
				giveEgg(finder)
			end
		end
	end
	if active.Culesul then
		if not cob and os.clock() >= nextCob then
			placeCob()
		end
		local current = cob
		if current then
			local finder = Kit.nearest(owners, current.Position, 4)
			if finder then
				current:Destroy()
				cob = nil
				nextCob = os.clock() + COB_EVERY
				local epics = {}
				for _, c in Creatures.list do
					if c.rarity == "Epic" then
						table.insert(epics, c.id)
					end
				end
				local seed = epics[math.random(1, #epics)]
				finder.profile.seeds[seed] = (finder.profile.seeds[seed] or 0) + 1
				Messenger.notify(finder.player, "season.cob", { Messenger.key("creature." .. seed) })
				StateService.markDirty(finder.player)
			end
		end
	end
end

function SeasonService.start()
	folder = Instance.new("Folder")
	folder.Name = "Sezon"
	folder.Parent = Workspace
	-- hramul: decorul dă +1% venit pe obiect așezat (cel mult +12%)
	EconomyService.seasonalMultiplier = function(owner: Owner): number
		if not active.Hram then
			return 1
		end
		return 1 + 0.01 * math.min(12, Decor.placedCount(owner.profile :: any))
	end
	Net.get("Season").OnServerEvent:Connect(function(player, action)
		local owner = PlotService.getOwner(player)
		if owner and typeof(action) == "string" and limiter:allow(player.UserId, os.clock()) then
			SeasonService.act(owner, action)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local actor = Actors.forPlayer(player)
		if actor then
			maskReady[actor] = nil
		end
	end)
	SeasonService.refresh()
	task.spawn(function()
		local last = 0
		while true do
			task.wait(TICK)
			if os.clock() - last >= 60 then
				last = os.clock()
				SeasonService.refresh() -- calendarul se schimbă rar: o verificare pe minut
			end
			local ok, err = pcall(tick :: any)
			if not ok then
				print("⚠ [Season] tick a eșuat:", err)
			end
		end
	end)
end

return SeasonService
