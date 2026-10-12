--!strict
-- Regizorul de playtest: un jucător real (clientul din Studio) contra unui jucător-bot.
-- Fiecare pas e jucat pe căile reale ale jocului și verificat pe server și pe client.
-- Rezultatele apar în Output cu prefixul [PLAYTEST]; ultimul rând e „[PLAYTEST] REZULTAT x/y”.

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Config.World)
local Creatures = require(Shared.Config.Creatures)
local Economy = require(Shared.Domain.Economy)
local walkModule: any = ReplicatedStorage:WaitForChild("PlaytestShared"):WaitForChild("Walk")
local Walk = (require :: any)(walkModule)

local serverFolder = ServerScriptService:WaitForChild("Server")
local services = (require :: any)(serverFolder:WaitForChild("Boot")).start()
local Actors = (require :: any)(serverFolder:WaitForChild("Actors"))
local PlotService = services.PlotService
local RaidService = services.RaidService
local CreatureService = services.CreatureService
local DayNightService = services.DayNightService
local BunicaService = services.BunicaService
local SlipperService = services.SlipperService
local TutorialService = services.TutorialService
local HoraService = services.HoraService
local Hora = require(Shared.Config.Hora)
local GameState = require(Shared.GameState)

local function log(message: string)
	print("[PLAYTEST] " .. message)
end

-- Canalul cu agentul de pe client
local command = Instance.new("RemoteEvent")
command.Name = "PlaytestCmd"
command.Parent = ReplicatedStorage
local reply = Instance.new("RemoteEvent")
reply.Name = "PlaytestReply"
reply.Parent = ReplicatedStorage

local pending: { [number]: { done: boolean, ok: boolean, result: any } } = {}
local clientReady = false
reply.OnServerEvent:Connect(function(_, id: number, ok: boolean, result: any)
	if id == 0 then
		clientReady = true
		return
	end
	local slot = pending[id]
	if slot then
		slot.done, slot.ok, slot.result = true, ok, result
	end
end)

local player: Player
local nextId = 0

local function call(op: string, ...: any): any
	nextId += 1
	local id = nextId
	pending[id] = { done = false, ok = false, result = nil }
	command:FireClient(player, id, op, { ... })
	local deadline = os.clock() + 60
	while not pending[id].done and os.clock() < deadline do
		task.wait(0.05)
	end
	local slot = pending[id]
	pending[id] = nil
	if not slot.done then
		error("clientul nu a răspuns la " .. op)
	end
	if not slot.ok then
		error("clientul a eșuat la " .. op .. ": " .. tostring(slot.result))
	end
	return slot.result
end

local passed, total = 0, 0
local function step(name: string, fn: () -> ())
	total += 1
	local ok, err = pcall(fn :: any)
	if ok then
		passed += 1
		log("✓ " .. name)
	else
		log("✗ " .. name .. " — " .. tostring(err))
	end
end

local function check(condition: any, message: string)
	if not condition then
		error(message, 2)
	end
end

local function waitFor(condition: () -> boolean, timeout: number): boolean
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		if condition() then
			return true
		end
		task.wait(0.2)
	end
	return condition()
end

local function count(t: any): number
	local n = 0
	for _ in t or {} do
		n += 1
	end
	return n
end

local function containsText(texts: { string }, pattern: string): boolean
	for _, text in texts do
		if string.find(text, pattern) then
			return true
		end
	end
	return false
end

local function firstPedestal(owner: any): string?
	local keys = {}
	for key in owner.profile.pedestals do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys[1]
end

-- Punctul de lângă o creatură, spre drum (de unde se ajunge la prompt)
local function approach(owner: any, key: string): Vector3
	local model = CreatureService.modelAt(owner, key) :: Model
	local position = model:GetPivot().Position + owner.plot.geometry.cframe.LookVector * 4.5
	return Vector3.new(position.X, owner.plot.geometry.cframe.Position.Y + 3, position.Z)
end

local function roadPoint(plot: any): Vector3
	return (plot.geometry.cframe * CFrame.new(0, 3, -World.plotSize.Z / 2 - 8)).Position
end

-- Iese din ograda proprie pe poartă (agentul de test nu trebuie să meargă în gard)
local function leaveHome(plot: any)
	local cf = plot.geometry.cframe
	call("walkTo", (cf * CFrame.new(0, 3, -World.plotSize.Z / 2 + 5)).Position, 3)
	call("walkTo", (cf * CFrame.new(0, 3, -World.plotSize.Z / 2 - 6)).Position, 3)
end

local function nearestNpcPlots(home: any): { any }
	local list = {}
	for _, plot in PlotService.plots do
		if plot ~= home and plot.owner and plot.owner.kind == "Npc" and plot.owner.actor == nil then
			table.insert(list, plot)
		end
	end
	table.sort(list, function(a, b)
		return (a.geometry.cframe.Position - home.geometry.cframe.Position).Magnitude
			< (b.geometry.cframe.Position - home.geometry.cframe.Position).Magnitude
	end)
	return list
end

-- Scenariul ---------------------------------------------------------------

player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
log("jucător: " .. player.Name)
check(
	waitFor(function()
		return clientReady and PlotService.getOwner(player) ~= nil
	end, 30),
	"jucătorul nu a primit ogradă sau clientul nu e gata"
)
task.wait(2)

BunicaService.setEnabled(false)
DayNightService.forcePhase("Day")
local me = PlotService.getOwner(player)
local myActor = Actors.forPlayer(player)
log("ograda jucătorului: " .. me.plot.index)
log("articulații: " .. table.concat(call("jointInfo", me.plot.index), " | "))

step("1. Sămânța de start eclozează pe un piedestal", function()
	check(
		waitFor(function()
			return count(me.profile.pedestals) >= 1
		end, 40),
		"nicio creatură pe piedestal după 40 s"
	)
	local seen = nil
	check(
		waitFor(function()
			seen = call("query")
			return seen.pedestals >= 1
		end, 3),
		"clientul nu vede creatura în stare"
	)
	check(containsText(seen.hud, "lei"), "HUD-ul nu afișează leii")
end)

step("1b. Primul minut: hoțul vine, jucătorul îl nimerește cu papucul", function()
	check(
		waitFor(function()
			return TutorialService.isWaitingForThrow(me)
		end, 70),
		"hoțul din tutorial nu a ajuns la aruncare"
	)
	local seen = call("query")
	check(table.find(seen.tutorial, "throw") ~= nil, "clientul nu a primit indiciul de aruncare")
	local serverRoot = Actors.root(myActor) :: BasePart
	local thiefRoot = Actors.root(TutorialService.thiefOf(me)) :: BasePart
	log(
		string.format(
			"poziții: client %s | server %s | acasă %s | hoț %s",
			tostring(seen.position),
			tostring(serverRoot.Position),
			tostring(me.plot.geometry.spawnCFrame.Position),
			tostring(thiefRoot.Position)
		)
	)
	check(call("throwAt", "Hoțomanul") == "ok", "clientul nu vede hoțul")
	task.wait(0.25)
	log("SNAP tutorial-lovitura")
	check(
		waitFor(function()
			return me.profile.tutorialThiefDone
		end, 6),
		"tutorialul nu s-a încheiat după aruncare"
	)
	check(
		waitFor(function()
			return table.find(call("query").tutorial, "done") ~= nil
		end, 3),
		"clientul nu a primit finalul tutorialului"
	)
end)

step("1c. Efectele sonore se încarcă", function()
	local failed = call("preloadSounds")
	check(#failed == 0, "sunete care nu se încarcă: " .. table.concat(failed, ", "))
end)

step("2. Leii cresc din venitul creaturilor", function()
	local before = me.profile.lei
	task.wait(3)
	check(me.profile.lei > before, string.format("lei %.1f → %.1f", before, me.profile.lei))
end)

step("3. Taraba se deschide și listează semințe", function()
	local rows = call("openShop")
	check(rows > 0, "taraba nu are rânduri")
end)

step("4. Cumpără o sămânță", function()
	local lei = me.profile.lei
	call("fire", "BuySeed", "CartofelAgent")
	check(
		waitFor(function()
			return (me.profile.seeds.CartofelAgent or 0) >= 1
		end, 5),
		"sămânța nu a ajuns în inventar"
	)
	check(me.profile.lei <= lei - 10 + 5, "leii nu au scăzut cu prețul semințelor")
end)

local plantedKey = "2"
step("5. Plantează prin prompt-ul stratului", function()
	local bed = me.plot.geometry.beds[plantedKey]
	local distance =
		call("walkTo", bed.Position + me.plot.geometry.cframe.LookVector * 4 + Vector3.new(0, 3, 0))
	check(distance < 8, "jucătorul nu a ajuns la strat (rămas " .. math.floor(distance) .. ")")
	task.wait(0.5)
	local result = call("holdPrompt", "PlantPrompt", nil, bed.Position)
	check(result == "ok", "prompt de plantare: " .. tostring(result))
	check(
		waitFor(function()
			return me.profile.beds[plantedKey] ~= nil
		end, 5),
		"planta nu apare pe server"
	)
	task.wait(1.5)
	check(call("query").plants >= 1, "clientul nu randează planta")
end)

step("6. Planta crește și eclozează", function()
	local before = count(me.profile.pedestals)
	check(
		waitFor(function()
			return me.profile.beds[plantedKey] == nil and count(me.profile.pedestals) > before
		end, 45),
		"planta nu a eclozat în 45 s"
	)
end)

step("7. Se lasă noaptea (HUD și lumină)", function()
	DayNightService.forcePhase("Night")
	task.wait(4)
	local seen = call("query")
	check(containsText(seen.hud, "Night") or containsText(seen.hud, "Noapte"), "HUD-ul nu arată noaptea")
	check(seen.clock < 5 or seen.clock > 20, "lumina nu s-a schimbat (ClockTime " .. seen.clock .. ")")
end)

local npcPlots = nearestNpcPlots(me.plot)
local victimPlot = npcPlots[1]
local stolenUid: string? = nil
step("8. Jucătorul fură de la vecinul NPC", function()
	local victim = victimPlot.owner
	local key = firstPedestal(victim) :: string
	stolenUid = victim.profile.pedestals[key].uid
	call("walkTo", roadPoint(me.plot))
	call("walkTo", roadPoint(victimPlot))
	local distance = call("walkTo", approach(victim, key))
	check(distance < 6, "nu a ajuns la creatură (rămas " .. math.floor(distance) .. ")")
	local model = CreatureService.modelAt(victim, key) :: Model
	local result = call("holdPrompt", "StealPrompt", victim.userId, model:GetPivot().Position)
	check(result == "ok", "prompt de furt: " .. tostring(result))
	check(
		waitFor(function()
			return RaidService.isCarrying(myActor)
		end, 3),
		"furtul nu a început"
	)
	check(call("query").walkSpeed < 16, "jucătorul nu e încetinit cât cară")
end)

step("9. Jucătorul depune creatura furată în beciul lui", function()
	call("walkTo", roadPoint(victimPlot))
	call("walkTo", roadPoint(me.plot))
	call("walkTo", me.plot.geometry.deposit.Position + Vector3.new(0, 3, 0), 2)
	check(
		waitFor(function()
			return not RaidService.isCarrying(myActor)
		end, 5),
		"încă cară creatura"
	)
	local found = false
	for _, record in me.profile.pedestals do
		found = found or record.uid == stolenUid
	end
	for _, record in me.profile.cellar do
		found = found or record.uid == stolenUid
	end
	check(found, "creatura furată nu e în inventarul jucătorului")
	check(me.profile.stats.steals == 1, "statistica de furturi nu a crescut")
end)

-- Botul: al doilea „jucător”, cu ograda lui
local botPlot = npcPlots[2]
local bot = Actors.createBot("HotBot", CFrame.new(roadPoint(me.plot)))
local botOwner = PlotService.assignBot(botPlot, bot)
local function botWalk(target: Vector3, tolerance: number?): number
	return Walk.to(Actors.characterOf(bot) :: Model, target, tolerance)
end

local defendedKey: string? = nil
step("10. Botul fură de la jucător și e lovit de papucul jucătorului", function()
	call("walkTo", me.plot.geometry.spawnCFrame.Position)
	local key = firstPedestal(me) :: string
	defendedKey = key
	local uid = me.profile.pedestals[key].uid
	check(botWalk(approach(me, key)) < 6, "botul nu a ajuns la creatură")
	RaidService.tryStart(bot, me, key)
	check(RaidService.isCarrying(bot), "botul nu a putut începe furtul")
	check(
		waitFor(function()
			return call("query").counters.Alarm >= 1
		end, 3),
		"jucătorul nu a primit alarma"
	)
	local nerviBefore = SlipperService.nervi(myActor)
	local bunicaRig = me.plot.geometry.model:FindFirstChild("Bunica") :: Model
	local lineSeqBefore = (bunicaRig:GetAttribute("LineSeq") :: number?) or 0
	call("throwAt", "HotBot")
	task.wait(0.25)
	log("SNAP noapte-lovitura")

	check(
		waitFor(function()
			return not RaidService.isCarrying(bot)
		end, 3),
		"papucul nu l-a nimerit pe bot"
	)
	check(RaidService.isStunned(bot), "botul nu e amețit")
	check(
		me.profile.pedestals[key] and me.profile.pedestals[key].uid == uid,
		"creatura nu s-a întors pe piedestal"
	)
	check(CreatureService.modelAt(me, key) ~= nil, "modelul creaturii nu a reapărut")
	check(SlipperService.nervi(myActor) == nerviBefore + 25, "Nervii nu au crescut cu 25")
	local seen = nil
	check(
		waitFor(function()
			seen = call("query")
			return seen.nervi == SlipperService.nervi(myActor)
		end, 3),
		"HUD-ul nu are Nervii actualizați"
	)
	check(
		seen.counters.Hit >= 1 and seen.counters.Projectile >= 1,
		"clientul nu a văzut proiectilul și lovitura"
	)
	check(
		table.find(seen.notifications, "notify.DefenseReward") ~= nil,
		"jucătorul nu a primit recompensa pentru apărare"
	)
	check(seen.papuci >= 1, "clasamentul nu arată apărările (Papuci = " .. tostring(seen.papuci) .. ")")
	-- Bunica sărbătorește cu bulă de dialog: prim-plan pentru captură
	local rig = me.plot.geometry.model:FindFirstChild("Bunica") :: Model
	local head = rig:FindFirstChild("Head") :: BasePart
	task.wait(0.5) -- lasă înghețarea camerei de la lovitură să se termine
	call("lookAt", head.Position, (head.CFrame * CFrame.new(0, 1, -7)).Position, 2.5)
	task.wait(0.6)
	log("SNAP bunica-sarbatoreste")
	local visuals = call("bunicaVisuals", me.plot.index)
	check(visuals.face, "Bunica nu are fața desenată")
	check(
		((rig:GetAttribute("LineSeq") :: number?) or 0) > lineSeqBefore,
		"Bunica nu a spus nimic la lovitură"
	)
	local line = rig:GetAttribute("Line")
	check(
		type(line) == "string" and string.find(line, "bunica.hit", 1, true) ~= nil,
		"replica nu e de lovitură"
	)
end)

step("11. Botul reușește un furt; jucătorul e anunțat și primește scut", function()
	task.wait(1.5) -- trece amețeala
	local key = defendedKey :: string
	local uid = me.profile.pedestals[key].uid
	botWalk(approach(me, key))
	RaidService.tryStart(bot, me, key)
	check(RaidService.isCarrying(bot), "al doilea furt nu a început")
	botWalk(roadPoint(me.plot))
	botWalk(roadPoint(botPlot))
	botWalk(botPlot.geometry.deposit.Position + Vector3.new(0, 3, 0), 2)
	check(
		waitFor(function()
			return not RaidService.isCarrying(bot)
		end, 5),
		"botul încă o cară"
	)
	check(me.profile.pedestals[key] == nil, "creatura a rămas la jucător")
	local moved = false
	for _, record in botOwner.profile.pedestals do
		moved = moved or record.uid == uid
	end
	check(moved, "creatura nu a ajuns la bot")
	check(me.shieldUntil > Workspace:GetServerTimeNow(), "jucătorul nu are scut")
	check(
		waitFor(function()
			return table.find(call("query").notifications, "notify.Stolen") ~= nil
		end, 3),
		"jucătorul nu a primit notificarea de furt"
	)
end)

step("12. Scutul blochează un nou furt", function()
	local key = firstPedestal(me) :: string
	botWalk(roadPoint(botPlot))
	botWalk(roadPoint(me.plot))
	botWalk(approach(me, key))
	RaidService.tryStart(bot, me, key)
	check(not RaidService.isCarrying(bot), "furtul a trecut prin scut")
end)

step("13. Vinde creatura furată de la vecin", function()
	local uid = stolenUid :: string
	local record = nil
	for _, r in me.profile.pedestals do
		if r.uid == uid then
			record = r
		end
	end
	check(record ~= nil, "creatura furată nu e pe piedestal")
	local lei = me.profile.lei
	call("fire", "Sell", uid)
	check(
		waitFor(function()
			return me.profile.lei >= lei + Economy.sellPrice(record) - 1
		end, 5),
		"leii nu au crescut cu prețul de vânzare"
	)
end)

step("14. Mută în beci și înapoi pe piedestal", function()
	local key = firstPedestal(me) :: string
	local uid = me.profile.pedestals[key].uid
	call("fire", "MoveToCellar", key)
	check(
		waitFor(function()
			return me.profile.pedestals[key] == nil and #me.profile.cellar >= 1
		end, 5),
		"nu s-a mutat în beci"
	)
	check(CreatureService.modelAt(me, key) == nil, "modelul a rămas pe piedestal")
	call("fire", "MoveToPedestal", uid)
	check(
		waitFor(function()
			for _, r in me.profile.pedestals do
				if r.uid == uid then
					return true
				end
			end
			return false
		end, 5),
		"nu s-a întors pe piedestal"
	)
end)

step("15. Bunica apără singură cât jucătorul e plecat", function()
	me.shieldUntil = 0
	leaveHome(me.plot)
	call("walkTo", roadPoint(npcPlots[3] or victimPlot))
	local key = firstPedestal(me) :: string
	botWalk(approach(me, key))
	RaidService.tryStart(bot, me, key)
	check(RaidService.isCarrying(bot), "botul nu a putut începe furtul")
	BunicaService.setEnabled(true) -- abia acum: altfel îl prinde înainte să apuce creatura
	local rig = me.plot.geometry.model:FindFirstChild("Bunica") :: Model
	local sawAwake = false
	local hit = waitFor(function()
		sawAwake = sawAwake or rig:GetAttribute("State") == "Awake"
		return not RaidService.isCarrying(bot)
	end, 15)
	check(hit, "Bunica nu l-a prins pe bot în 15 s")
	check(sawAwake, "Bunica nu a trecut prin starea Awake")
	check(me.profile.pedestals[key] ~= nil, "creatura nu a rămas la jucător")
end)

step("15b. La răsărit se reia lovitura nopții", function()
	DayNightService.forcePhase("Day")
	task.wait(1.5)
	log("SNAP reluare")
	check(
		waitFor(function()
			return call("query").counters.Replay >= 1
		end, 5),
		"clientul nu a primit reluarea loviturii nopții"
	)
	task.wait(4) -- lasă reluarea să se termine (capturi)
end)

step("15c. Hora: jucătorul dansează la fântână cu doi vecini și cheamă o vreme rară", function()
	HoraService.resetCooldown()
	local dancers = {}
	for i = 1, 2 do
		local angle = i * math.pi
		local position = Hora.center + Vector3.new(math.cos(angle) * 6, 3, math.sin(angle) * 6)
		local dancer = Actors.createBot("Dansator" .. i, CFrame.new(position))
		HoraService.setDancing(dancer, 30)
		table.insert(dancers, dancer)
	end
	local distance = call("walkTo", Hora.center + Vector3.new(0, 3, 6), 3)
	check(distance < 6, "jucătorul nu a ajuns la fântână (rămas " .. math.floor(distance) .. ")")
	call("fire", "Hora")
	task.wait(1)
	log("SNAP hora")
	check(
		waitFor(function()
			local weather = GameState.get("Weather")
			return weather == "GoldHarvest" or weather == "Rainbow"
		end, 8),
		"Hora nu a chemat vremea rară"
	)
	for _, dancer in dancers do
		Actors.removeBot(dancer)
	end
end)

step("16. Fără erori de script (server și client)", function()
	local serverErrors = {}
	for _, entry in LogService:GetLogHistory() do
		if
			entry.messageType == Enum.MessageType.MessageError
			and not string.find(entry.message, "PLAYTEST", 1, true)
		then
			table.insert(serverErrors, entry.message)
		end
	end
	local clientErrors = call("query").errors
	check(#serverErrors == 0, "erori pe server: " .. table.concat(serverErrors, " | "))
	check(#clientErrors == 0, "erori pe client: " .. table.concat(clientErrors, " | "))
end)

local _ = Creatures
Actors.removeBot(bot)
DayNightService.forcePhase(nil)
log(string.format("REZULTAT %d/%d", passed, total))
