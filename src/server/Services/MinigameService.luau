--!strict
-- Mini-jocurile (Domain/Minigame, Config/Minigames): o rundă se deschide la locul ei (propusă de ceasul satului
-- sau cerută de un jucător de lângă loc), are 20 s de înscriere, numărătoarea 3-2-1, apoi rulează modulul
-- jocului din src/server/Minigames:
--   setup(match), tick(match, dt), action(match, owner, payload), finish(match): { [userId]: scor }
-- match: { def, players: { Owner }, scores, reachedAt, arena: CFrame, startedAt, endsAt, folder, data,
--          score(owner, delta), eliminate(owner), isGhost(owner), cheers, publish(extra), finish() }.
-- La final: răsplata pentru toți cei rămași (podiumul în plus), curățenie totală.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Minigames = require(Shared.Config.Minigames)
local Minigame = require(Shared.Domain.Minigame)
local VillageLayout = require(Shared.Domain.VillageLayout)
local RateLimiter = require(Shared.Domain.RateLimiter)
local Actors = require(script.Parent.Parent.Actors)
local Busy = require(script.Parent.Parent.Busy)
local PlotService = require(script.Parent.PlotService)
local EconomyService = require(script.Parent.EconomyService)
local StateService = require(script.Parent.StateService)
local Messenger = require(script.Parent.Messenger)
local Analytics = require(script.Parent.Parent.Analytics)

type Owner = PlotService.Owner
export type Match = {
	def: Minigames.Minigame,
	players: { Owner },
	scores: { [number]: number },
	reachedAt: { [number]: number },
	arena: CFrame,
	startedAt: number,
	endsAt: number,
	folder: Folder,
	data: { [string]: any },
	ghosts: { [Owner]: boolean },
	cheers: { [string]: number }, -- încurajări pe echipă (cheia echipei; "all" când nu sunt echipe)
	score: (owner: Owner, delta: number) -> (),
	eliminate: (owner: Owner) -> (),
	isGhost: (owner: Owner) -> boolean,
	publish: (extra: { [string]: any }) -> (),
	finish: () -> (),
}
type Module = {
	setup: (Match) -> (),
	tick: ((Match, number) -> ())?,
	action: ((Match, Owner, any) -> ())?,
	finish: ((Match) -> { [number]: number })?,
	teamOf: ((Match, Owner) -> string)?,
}
type Lobby = { def: Minigames.Minigame, enrolled: { Owner }, closesAt: number }

local MinigameService = {}

local TICK = 0.1
local modules: { [string]: Module } = {}
local defs: { [string]: Minigames.Minigame } = table.clone(Minigames.byId)
local lobbies: { [string]: Lobby } = {} -- după loc
local matches: { [string]: { match: Match, module: Module, done: boolean } } = {} -- după loc
local sites = VillageLayout.build().sites
local limiter = RateLimiter.new(8, 2)

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function broadcast(payload: { [string]: any })
	Net.get("Minigame"):FireAllClients(payload)
end

-- Pentru teste: înregistrează un joc (definiția și modulul) fără fișier în src/server/Minigames
function MinigameService.register(def: Minigames.Minigame, module: Module)
	defs[def.id] = def
	modules[def.id] = module
end

function MinigameService.matchAt(site: string): Match?
	local entry = matches[site]
	return if entry then entry.match else nil
end

function MinigameService.lobbyAt(site: string): Lobby?
	return lobbies[site]
end

function MinigameService.isPlaying(owner: Owner): boolean
	return owner.actor ~= nil and Busy.is(owner.actor)
end

local function rootOf(owner: Owner): BasePart?
	return if owner.actor then Actors.root(owner.actor) else nil
end

local function nearSite(owner: Owner, site: string): boolean
	local root = rootOf(owner)
	local cf: CFrame? = sites[site]
	if not root or not cf then
		return false
	end
	return Vector3.new(root.Position.X - cf.X, 0, root.Position.Z - cf.Z).Magnitude
		<= Minigames.enrollDistance
end

local function finishMatch(site: string)
	local entry = matches[site]
	if not entry or entry.done then
		return
	end
	entry.done = true
	local match, module = entry.match, entry.module
	local scores = match.scores
	if module.finish then
		local ok, result = pcall(module.finish :: any, match)
		if ok and typeof(result) == "table" then
			scores = result
		elseif not ok then
			print("⚠ [Minigame] finish a eșuat:", result)
		end
	end
	local present: { [number]: boolean } = {}
	local byId: { [number]: Owner } = {}
	for _, owner in match.players do
		if owner.plot.owner == owner and owner.actor and owner.actor.alive then
			present[owner.userId] = true
			byId[owner.userId] = owner
		end
		if owner.actor then
			Busy.set(owner.actor, nil)
		end
	end
	local ranking = Minigame.rank(scores, match.reachedAt)
	local rewards = Minigame.rewards(match.def, ranking, present, scores)
	local podium = {}
	for place, id in ranking do
		if present[id] and #podium < 3 then
			table.insert(podium, { userId = id, name = byId[id] and byId[id].name or "", place = place })
		end
	end
	for id, lei in rewards do
		local owner = byId[id]
		if owner and lei > 0 then
			EconomyService.addLei(owner, lei)
			Analytics.source(owner.player, owner.profile, lei, "Minigame")
			StateService.markDirty(owner.player)
			if owner.player then
				local place = table.find(ranking, id)
				if
					place
					and place <= 3
					and match.def.rewards.placements[place]
					and match.def.rewards.placements[place] > 0
				then
					Messenger.notify(
						owner.player,
						"minigame.won",
						{ Messenger.key("minigame." .. match.def.id), tostring(place), tostring(lei) }
					)
				else
					Messenger.notify(
						owner.player,
						"minigame.played",
						{ Messenger.key("minigame." .. match.def.id), tostring(lei) }
					)
				end
			end
		end
	end
	match.folder:Destroy()
	matches[site] = nil
	broadcast({ id = match.def.id, site = site, state = "results", podium = podium, rewards = rewards })
end

local function startMatch(lobby: Lobby)
	local def = lobby.def
	local module = modules[def.id]
	local site = def.site
	lobbies[site] = nil
	local players = {}
	for _, owner in lobby.enrolled do
		if owner.plot.owner == owner and owner.actor and owner.actor.alive and not Busy.is(owner.actor) then
			table.insert(players, owner)
		end
	end
	if #players < def.minPlayers or not module then
		for _, owner in lobby.enrolled do
			if owner.player then
				Messenger.notify(owner.player, "minigame.notEnough", { Messenger.key("minigame." .. def.id) })
			end
		end
		broadcast({ id = def.id, site = site, state = "cancelled" })
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Minigame_" .. def.id
	folder.Parent = Workspace
	local t = now() + Minigames.countdown
	local match: Match
	match = {
		def = def,
		players = players,
		scores = {},
		reachedAt = {},
		arena = sites[site] or CFrame.new(),
		startedAt = t,
		endsAt = t + def.durationSeconds,
		folder = folder,
		data = {},
		ghosts = {},
		cheers = {},
		score = function(owner: Owner, delta: number)
			match.scores[owner.userId] = (match.scores[owner.userId] or 0) + delta
			match.reachedAt[owner.userId] = os.clock()
		end,
		eliminate = function(owner: Owner)
			match.ghosts[owner] = true
			if owner.player then
				Messenger.notify(owner.player, "minigame.ghost")
			end
		end,
		isGhost = function(owner: Owner): boolean
			return match.ghosts[owner] == true
		end,
		publish = function(extra: { [string]: any })
			broadcast({
				id = def.id,
				site = site,
				state = "running",
				endsAt = match.endsAt,
				scores = match.scores,
				extra = extra,
			})
		end,
		finish = function()
			task.defer(finishMatch, site)
		end,
	}
	for _, owner in players do
		match.scores[owner.userId] = 0
		Busy.set(owner.actor, def.id)
	end
	matches[site] = { match = match, module = module, done = false }
	local ids = {}
	for _, owner in players do
		table.insert(ids, owner.userId)
	end
	broadcast({
		id = def.id,
		site = site,
		state = "countdown",
		startsAt = t,
		endsAt = match.endsAt,
		players = ids,
	})
	local ok, err = pcall(module.setup :: any, match)
	if not ok then
		print("⚠ [Minigame] setup a eșuat:", err)
		finishMatch(site)
	end
end

-- Deschide înscrierea la un joc (20 s, la locul lui). false dacă locul e ocupat sau jocul nu există.
function MinigameService.open(id: string, enrollSeconds: number?): boolean
	local def = defs[id]
	if not def or not modules[id] or lobbies[def.site] or matches[def.site] then
		return false
	end
	local closesAt = now() + (enrollSeconds or Minigames.enrollSeconds)
	lobbies[def.site] = { def = def, enrolled = {}, closesAt = closesAt }
	broadcast({
		id = id,
		site = def.site,
		state = "enroll",
		closesAt = closesAt,
		location = (sites[def.site] or CFrame.new()).Position,
	})
	return true
end

-- Înscrie un jucător (sau bot) aflat lângă loc
function MinigameService.join(owner: Owner, id: string): boolean
	local def = defs[id]
	local lobby = def and lobbies[def.site]
	if not lobby or lobby.def.id ~= id or not owner.actor or Busy.is(owner.actor) then
		return false
	end
	if table.find(lobby.enrolled, owner) then
		return true
	end
	if #lobby.enrolled >= def.maxPlayers then
		return false
	end
	if not nearSite(owner, def.site) then
		if owner.player then
			Messenger.notify(owner.player, "minigame.far")
		end
		return false
	end
	table.insert(lobby.enrolled, owner)
	if owner.player then
		Messenger.notify(owner.player, "minigame.joined")
	end
	broadcast({
		id = id,
		site = def.site,
		state = "enroll",
		closesAt = lobby.closesAt,
		enrolled = #lobby.enrolled,
	})
	return true
end

-- Pentru teste: închide înscrierea acum
function MinigameService.closeEnrollment(site: string)
	local lobby = lobbies[site]
	if lobby then
		lobby.closesAt = 0
	end
end

-- Acțiunea unui participant în jocul lui
function MinigameService.act(owner: Owner, payload: any)
	local id = owner.actor and Busy.get(owner.actor)
	local def = id and defs[id]
	local entry = def and matches[def.site]
	if not entry or entry.done then
		return
	end
	if typeof(payload) == "table" and payload.cheer == true and entry.match.ghosts[owner] then
		local module = entry.module
		local team = if module.teamOf then module.teamOf(entry.match, owner) else "all"
		entry.match.cheers[team] = (entry.match.cheers[team] or 0) + 1
		return
	end
	if entry.module.action and now() >= entry.match.startedAt then
		local ok, err = pcall(entry.module.action :: any, entry.match, owner, payload)
		if not ok then
			print("⚠ [Minigame] action a eșuat:", err)
		end
	end
end

-- Oprește jocul de la un loc acum (răsplata se dă)
function MinigameService.stop(site: string)
	finishMatch(site)
end

-- Propunerea ceasului satului: un joc la întâmplare, care se poate juca cu câți sunt pe server
function MinigameService.propose(players: number): string?
	local options = {}
	for id, def in defs do
		if
			modules[id]
			and def.minPlayers <= math.max(players, 1)
			and not lobbies[def.site]
			and not matches[def.site]
		then
			table.insert(options, id)
		end
	end
	if #options == 0 then
		return nil
	end
	local id = options[math.random(1, #options)]
	return if MinigameService.open(id) then id else nil
end

local function tick()
	local t = now()
	for _, lobby in lobbies do
		if t >= lobby.closesAt then
			startMatch(lobby)
		end
	end
	for site, entry in matches do
		if entry.done then
			continue
		end
		local match = entry.match
		-- cine a plecat de pe server iese din joc
		for _, owner in match.players do
			if owner.plot.owner ~= owner and owner.actor then
				Busy.set(owner.actor, nil)
			end
		end
		if t >= match.startedAt and entry.module.tick then
			local ok, err = pcall(entry.module.tick :: any, match, TICK)
			if not ok then
				print("⚠ [Minigame] tick a eșuat:", err)
			end
		end
		if t >= match.endsAt then
			finishMatch(site)
		end
	end
end

function MinigameService.init()
	local server = ServerScriptService:FindFirstChild("Server")
	local folder = server and server:FindFirstChild("Minigames")
	for _, def in Minigames.list do
		local module = folder and folder:FindFirstChild(def.id)
		if module and module:IsA("ModuleScript") then
			modules[def.id] = (require :: any)(module)
		end
	end
end

-- Pentru panoul clientului: jocurile care există (au modul)
function MinigameService.available(): { string }
	local list = {}
	for id in modules do
		table.insert(list, id)
	end
	table.sort(list)
	return list
end

function MinigameService.start()
	Net.get("MinigameAction").OnServerEvent:Connect(function(player, action, arg)
		if not limiter:allow(player.UserId, os.clock()) then
			return
		end
		local owner = PlotService.getOwner(player)
		if not owner then
			return
		end
		if action == "open" and typeof(arg) == "string" then
			-- un jucător de lângă loc deschide o rundă (dacă locul e liber) și intră primul
			local def = defs[arg]
			if def and not lobbies[def.site] and nearSite(owner, def.site) then
				MinigameService.open(arg)
			end
			MinigameService.join(owner, arg)
		elseif action == "join" and typeof(arg) == "string" then
			MinigameService.join(owner, arg)
		elseif action == "act" then
			MinigameService.act(owner, arg)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local actor = Actors.forPlayer(player)
		if actor then
			Busy.set(actor, nil)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			local ok, err = pcall(tick :: any)
			if not ok then
				print("⚠ [Minigame] ceasul a eșuat:", err)
			end
		end
	end)
end

return MinigameService
