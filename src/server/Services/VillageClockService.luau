--!strict
-- Ceasul satului (Domain/VillageClock, Config/Happenings): la 6–8 minute o întâmplare pentru tot serverul,
-- anunțată cu 30 s înainte, cel mult una activă. Fiecare întâmplare e un modul din src/server/Happenings:
--   start(ctx), action(ctx, owner, payload), stop(ctx): { [Owner]: number } (locul pe podium; 0 = doar a participat)
-- ctx: { def, site: CFrame, endsAt, folder (curățat la final), owners(), give(owner, lei), participate(owner),
--        finish() (oprire înainte de vreme), publish(extra) (date pentru clienți) }.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local GameState = require(Shared.GameState)
local Happenings = require(Shared.Config.Happenings)
local Village = require(Shared.Config.Village)
local VillageClock = require(Shared.Domain.VillageClock)
local VillageLayout = require(Shared.Domain.VillageLayout)
local RateLimiter = require(Shared.Domain.RateLimiter)
local PlotService = require(script.Parent.PlotService)
local EconomyService = require(script.Parent.EconomyService)
local StateService = require(script.Parent.StateService)
local Messenger = require(script.Parent.Messenger)
local Analytics = require(script.Parent.Parent.Analytics)
local Progress = require(script.Parent.Parent.Progress)

type Owner = PlotService.Owner
export type Context = {
	def: Happenings.Happening,
	site: CFrame,
	startedAt: number,
	endsAt: number,
	folder: Folder,
	owners: () -> { Owner },
	give: (owner: Owner, lei: number) -> (),
	participate: (owner: Owner) -> (),
	participants: { [Owner]: boolean },
	finish: () -> (),
	publish: (extra: { [string]: any }) -> (), -- date pentru clienți (oferta negustorului, poziția nunții)
	data: { [string]: any }, -- starea proprie a întâmplării
}
type Module = {
	start: (Context) -> (),
	action: ((Context, Owner, any) -> ())?,
	tick: ((Context, number) -> ())?,
	stop: (Context) -> { [Owner]: number },
}

local VillageClockService = {}

local TICK = 0.25
local modules: { [string]: Module } = {}
local history: { [string]: number } = {}
local scheduled: { id: string, startAt: number, warned: boolean }? = nil
local proposeAt: number? = nil -- la jumătatea pauzei dintre întâmplări, ceasul propune un mini-joc
local active: { ctx: Context, module: Module, finished: boolean }? = nil
local enabled = true
local limiter = RateLimiter.new(10, 2)
local sites = VillageLayout.build().sites
local rng = Random.new()

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function siteOf(def: Happenings.Happening): CFrame
	local site = sites[def.location]
	return site or CFrame.new(Village.hub)
end

local function broadcast(payload: { [string]: any })
	Net.get("Happening"):FireAllClients(payload)
end

-- Pentru e2e și ceas: modulele întâmplărilor care există
function VillageClockService.available(): { [string]: boolean }
	local set = {}
	for id in modules do
		set[id] = true
	end
	return set
end

function VillageClockService.active(): Context?
	return if active then active.ctx else nil
end

function VillageClockService.scheduled(): (string?, number?)
	if scheduled then
		return scheduled.id, scheduled.startAt
	end
	return nil, nil
end

-- Pentru teste: ceasul nu mai programează singur
function VillageClockService.setEnabled(on: boolean)
	enabled = on
	if not on then
		scheduled = nil
	end
end

local function phaseAt(t: number): string
	local phase = GameState.get(GameState.Attributes.Phase) or "Day"
	local endsAt = GameState.get(GameState.Attributes.PhaseEndsAt)
	if typeof(endsAt) == "number" and t >= endsAt then
		return if phase == "Day" then "Night" else "Day"
	end
	return phase
end

local function schedule()
	local players = #Players:GetPlayers()
	local guess = now()
	local id, startAt = VillageClock.next(
		guess,
		phaseAt(guess + Happenings.minGap),
		players,
		history,
		function()
			return rng:NextNumber()
		end,
		VillageClockService.available()
	)
	scheduled = if id then { id = id, startAt = startAt, warned = false } else nil
	proposeAt = guess + (startAt - guess) / 2
end

local function finishActive()
	local current = active
	if not current or current.finished then
		return
	end
	current.finished = true
	local ctx = current.ctx
	local ok, placements = pcall(current.module.stop, ctx)
	if not ok then
		print("⚠ [VillageClock] stop a eșuat:", placements)
		placements = {}
	end
	local results: { [number]: number } = {}
	for owner in ctx.participants do
		local placement = (placements :: any)[owner]
		local lei = VillageClock.reward(true, if placement and placement > 0 then placement else nil)
		if owner.plot.owner == owner then
			EconomyService.addLei(owner, lei)
			Analytics.source(owner.player, owner.profile, lei, "Happening")
			StateService.markDirty(owner.player)
		end
		results[owner.userId] = lei
		Progress.emit(owner, "happening")
		if owner.player then
			Messenger.notify(
				owner.player,
				"happening.reward",
				{ Messenger.key("happening." .. ctx.def.id), tostring(lei) }
			)
		end
	end
	ctx.folder:Destroy()
	broadcast({ id = ctx.def.id, state = "end" })
	active = nil
end

-- Pornește întâmplarea acum (ceasul, sau testele). Întoarce false dacă una e deja activă sau lipsește modulul.
function VillageClockService.begin(id: string, durationSeconds: number?): boolean
	local def = Happenings.byId[id]
	local module = modules[id]
	if active or not def or not module then
		return false
	end
	local t = now()
	local folder = Instance.new("Folder")
	folder.Name = "Happening_" .. id
	folder.Parent = Workspace
	local ctx: Context
	ctx = {
		def = def,
		site = siteOf(def),
		startedAt = t,
		endsAt = t + (durationSeconds or def.durationSeconds),
		folder = folder,
		owners = function()
			local list = {}
			for _, owner in PlotService.owners() do
				if owner.kind == "Player" or owner.standIn then
					table.insert(list, owner)
				end
			end
			return list
		end,
		give = function(owner: Owner, lei: number)
			EconomyService.addLei(owner, lei)
			StateService.markDirty(owner.player)
		end,
		participate = function(owner: Owner)
			ctx.participants[owner] = true
		end,
		participants = {},
		finish = function()
			task.defer(finishActive)
		end,
		publish = function(extra: { [string]: any })
			broadcast({
				id = id,
				state = "active",
				endsAt = ctx.endsAt,
				location = ctx.site.Position,
				extra = extra,
			})
		end,
		data = {},
	}
	history[id] = t
	active = { ctx = ctx, module = module, finished = false }
	-- anunțul întâi: datele publicate de modul în start (oferta negustorului) vin după el și nu se pierd
	broadcast({ id = id, state = "active", endsAt = ctx.endsAt, location = ctx.site.Position })
	local ok, err = pcall(module.start :: any, ctx)
	if not ok then
		print("⚠ [VillageClock] start a eșuat:", err)
		finishActive()
		return false
	end
	return true
end

-- Acțiunea unui jucător (sau bot) în întâmplarea activă
function VillageClockService.act(owner: Owner, payload: any)
	local current = active
	if current and current.module.action then
		local ok, err = pcall(current.module.action :: any, current.ctx, owner, payload)
		if not ok then
			print("⚠ [VillageClock] action a eșuat:", err)
		end
	end
end

-- Oprește întâmplarea activă acum (răsplata se dă)
function VillageClockService.stop()
	finishActive()
end

local function tick()
	local t = now()
	local current = active
	if current then
		if current.module.tick then
			local ok, err = pcall(current.module.tick :: any, current.ctx, TICK)
			if not ok then
				print("⚠ [VillageClock] tick a eșuat:", err)
			end
		end
		if t >= current.ctx.endsAt then
			finishActive()
		end
		return
	end
	if not enabled then
		return
	end
	if not scheduled then
		schedule()
		return
	end
	if proposeAt and t >= proposeAt then
		proposeAt = nil
		local MinigameService = (require :: any)(script.Parent.MinigameService)
		MinigameService.propose(#Players:GetPlayers())
	end
	local plan = scheduled :: { id: string, startAt: number, warned: boolean }
	local def = Happenings.byId[plan.id]
	if not plan.warned and t >= plan.startAt - def.warnSeconds then
		plan.warned = true
		broadcast({ id = plan.id, state = "warn", startsAt = plan.startAt, location = siteOf(def).Position })
	end
	if t >= plan.startAt then
		scheduled = nil
		VillageClockService.begin(plan.id)
	end
end

function VillageClockService.init()
	local folder = ServerScriptService:FindFirstChild("Server")
	local happenings = folder and folder:FindFirstChild("Happenings")
	for _, def in Happenings.list do
		local module = happenings and happenings:FindFirstChild(def.id)
		if module and module:IsA("ModuleScript") then
			modules[def.id] = (require :: any)(module)
		end
	end
	history.Tren = now() -- trenul vine prima dată după o oră
end

function VillageClockService.start()
	Net.get("HappeningAction").OnServerEvent:Connect(function(player, payload)
		if not limiter:allow(player.UserId, os.clock()) then
			return
		end
		local owner = PlotService.getOwner(player)
		if owner then
			VillageClockService.act(owner, payload)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			local ok, err = pcall(tick :: any)
			if not ok then
				print("⚠ [VillageClock] ceasul a eșuat:", err)
			end
		end
	end)
end

return VillageClockService
