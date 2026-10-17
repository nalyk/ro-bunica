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
local Net = require(Shared.Net)
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
local LiveEventService = services.LiveEventService
local ShopService = services.ShopService
local NpcThiefService = services.NpcThiefService
local FamilyService = services.FamilyService
local TradeService = services.TradeService
local StateService = services.StateService
local Inventory = require(Shared.Domain.Inventory)
local NpcThieves = require(Shared.Domain.NpcThieves)
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
NpcThiefService.setEnabled(false) -- hoții vecini doar în pasul lor, ca să nu încurce celelalte scene
DayNightService.forcePhase("Day")
local me = PlotService.getOwner(player)
local myActor = Actors.forPlayer(player)
log("ograda jucătorului: " .. me.plot.index)
log("articulații: " .. table.concat(call("jointInfo", me.plot.index), " | "))

step("0. Ecranul de încărcare se termină singur și reface interfața Roblox", function()
	check(
		waitFor(function()
			return not call("loading", "state").present
		end, 45),
		"ecranul de încărcare nu s-a închis"
	)
	local state = call("loading", "state")
	check(state.playerList and state.chat, "lista de jucători sau chatul n-au revenit după încărcare")
end)

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

-- Galeria vizuală: camera se oprește în fața modelelor, cu o captură pentru fiecare (verificare cu ochiul)
local function photograph(name: string, target: Vector3, from: Vector3)
	call("lookAt", target, from, 2.5)
	task.wait(1.2)
	log("SNAP galerie-" .. name)
	task.wait(1.4)
end

-- Drumul parcurs de hoțul din tutorial (rig sculptat, mers prin Humanoid), eșantionat tot timpul scenei:
-- verificarea nu depinde de momentul în care ajunge testul la pasul 1b
local thiefPath = 0
task.spawn(function()
	local last: Vector3? = nil
	while not me.profile.tutorialThiefDone do
		local thief = TutorialService.thiefOf(me)
		local root = thief and Actors.root(thief)
		if root then
			if last then
				thiefPath += Vector3.new(root.Position.X - last.X, 0, root.Position.Z - last.Z).Magnitude
			end
			last = root.Position
		end
		task.wait(0.2)
	end
end)

step("1a. Galeria: creatura proprie, vecinii, Bunica, casa", function()
	local cf = me.plot.geometry.cframe
	for key in me.profile.pedestals do
		local model = CreatureService.modelAt(me, key)
		if model then
			local p = model:GetPivot().Position
			photograph(
				"creatura",
				p + Vector3.new(0, 1.8, 0),
				(CFrame.new(p) * cf.Rotation * CFrame.new(1.5, 3, -9)).Position
			)
		end
		break
	end
	local npc = nearestNpcPlots(me.plot)[1]
	if npc then
		local plotCf = npc.geometry.cframe
		local target = (plotCf * CFrame.new(18, 1.5, -10)).Position
		photograph("vecini", target, (plotCf * CFrame.new(10, 9, -34)).Position)
	end
	local bunica = me.plot.geometry.bunicaCFrame.Position
	photograph(
		"bunica",
		bunica + Vector3.new(0, 2.5, 0),
		(cf * CFrame.new(-2, 5, World.plotSize.Z / 2 - 30)).Position
	)
	photograph(
		"casa",
		(cf * CFrame.new(0, 6, World.plotSize.Z / 2 - 9)).Position,
		(cf * CFrame.new(-25, 14, -5)).Position
	)
	photograph("sat", cf.Position, (cf * CFrame.new(0, 45, -110)).Position)
	-- proiectilele sculptate (papucul, făcălețul), trimise prin evenimentul real, plutind încet fără gravitație
	local spot = (cf * CFrame.new(-12, 4, -22)).Position
	for i, kind in { "Slipper", "RollingPin" } do
		Net.get("Projectile"):FireAllClients({
			id = -100 - i,
			kind = kind,
			origin = spot + cf.RightVector * (if i == 1 then -2.2 else 2.2),
			velocity = Vector3.new(0, 0.05, 0),
			gravity = 0,
			lifetime = 8,
			startTime = workspace:GetServerTimeNow(),
			throwerUserId = 0,
			plotIndex = me.plot.index,
		})
	end
	photograph("proiectile", spot, (cf * CFrame.new(-12, 5.5, -30)).Position)
	local projectiles = call("projectiles") :: { string }
	log("proiectile: " .. table.concat(projectiles, "; "))
	check(#projectiles == 2, "clientul nu are cele două proiectile sculptate")
	for _, line in projectiles do
		check(
			string.match(line, "^prop%.") ~= nil and not string.find(line, " 0/", 1, true),
			"proiectil fără model texturat: " .. line
		)
	end
	call("fontTest", 3)
	task.wait(1.5)
	log("SNAP fonturi")
	task.wait(2)
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
	-- Hoțomanul sculptat fuge cu creatura: captură de aproape și verificare că rig-ul propriu chiar merge
	local thiefModel = Actors.characterOf(TutorialService.thiefOf(me)) :: Model
	-- camera în fața lui, pe direcția de mers (spre drum), ușor din lateral, ca să se vadă și creatura cărată
	call(
		"lookAt",
		thiefRoot.Position + Vector3.new(0, 2.5, 0),
		(thiefRoot.CFrame * CFrame.new(5, 3.5, -13)).Position,
		2
	)
	task.wait(1)
	log("SNAP hotoman-fuge")
	task.wait(0.4)
	local moved = thiefPath
	local box, size = thiefModel:GetBoundingBox()
	local feet = box.Position.Y - size.Y / 2
	-- solul de sub el (drumul nu e la nivelul ogrăzii): rază în jos, fără hoț și creatura lui
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { thiefModel }
	local hit = workspace:Raycast(thiefRoot.Position, Vector3.new(0, -20, 0), params)
	local floor = if hit then hit.Position.Y else me.plot.geometry.cframe.Position.Y
	log(
		string.format(
			"hoț: sculptat %s, a mers %.1f studs, tălpile la y %.2f, solul la y %.2f (%s)",
			tostring(thiefModel:GetAttribute("Sculpted")),
			moved,
			feet,
			floor,
			if hit then hit.Instance:GetFullName() else "-"
		)
	)
	check(moved > 15, string.format("hoțul nu merge (%.1f studs parcurși în toată scena)", moved))
	check(
		math.abs(feet - floor) < 0.5,
		string.format("tălpile hoțului nu sunt pe sol (%.2f față de %.2f)", feet, floor)
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
	local shop = call("openPanel", "ShopPanel")
	log(string.format("taraba: %d rânduri, %d previzualizări 3D", shop.rows, shop.previews))
	check(shop.rows > 0, "taraba nu are rânduri")
	check(shop.previews == shop.rows, "nu toate rândurile tarabei au creatura în 3D")
	task.wait(0.6)
	log("SNAP taraba")
	task.wait(1)
	call("closePanel", "ShopPanel")
	-- Gamepad: ținta în centru, glifele pe butoanele HUD-ului, selecția sare în panou
	local pad = call("gamepad", "on")
	log(
		string.format(
			"gamepad: %d glife, țintă %s, acțiuni legate %s/%s",
			pad.glyphs,
			tostring(pad.reticle),
			tostring(pad.bound),
			tostring(pad.closeBound)
		)
	)
	check(pad.glyphs == 8 and pad.reticle and pad.bound and pad.closeBound, "modul gamepad incomplet")
	task.wait(0.5)
	log("SNAP gamepad")
	task.wait(1)
	local padShop = call("gamepad", "shop")
	log("gamepad, selecția în tarabă: " .. tostring(padShop.selected))
	check(padShop.inPanel and padShop.reticleHidden, "la gamepad, selecția nu e în tarabă")
	task.wait(0.4)
	log("SNAP gamepad-taraba")
	task.wait(1)
	local padOff = call("gamepad", "off")
	check(padOff.selected == "nimic", "selecția UI a rămas după închiderea tarabei")
end)

step("3b. Panoul Ograda: cumpără un piedestal cu lei", function()
	me.profile.lei += 200
	services.EconomyService.addLei(me, 0)
	local before = me.profile.pedestalCount
	local panel = call("openPanel", "UpgradePanel")
	log(string.format("ograda: %d rânduri", panel.rows))
	check(panel.rows == 7, "panoul Ograda nu are cele 7 îmbunătățiri")
	call("fire", "BuyUpgrade", "pedestal")
	check(
		waitFor(function()
			return me.profile.pedestalCount == before + 1
		end, 5),
		"piedestalul nu s-a cumpărat"
	)
	task.wait(0.8)
	log("SNAP ograda")
	task.wait(1)
	call("closePanel", "UpgradePanel")
	-- Grivei apare lângă prispă după cumpărare
	me.profile.lei += 10000
	services.EconomyService.addLei(me, 0)
	call("fire", "BuyUpgrade", "dog")
	check(
		waitFor(function()
			return me.plot.geometry.model:FindFirstChild("Grivei") ~= nil
		end, 5),
		"Grivei nu a apărut în ogradă"
	)
	local dog = me.plot.geometry.model:FindFirstChild("Grivei") :: Model
	local dogAt = dog:GetPivot().Position
	call(
		"lookAt",
		dogAt + Vector3.new(0, 1.6, 0),
		-- din fața lui, dinspre drum (LookVector-ul ogrăzii arată spre drum), puțin din dreapta
		dogAt
			+ me.plot.geometry.cframe.LookVector * 9
			+ me.plot.geometry.cframe.RightVector * 3
			+ Vector3.new(0, 3.5, 0),
		2
	)
	task.wait(1.2)
	log("SNAP grivei")
	task.wait(1)
end)

step("3c. Magazinul pe Robux: permisele și produsele, cu prețurile de la Roblox", function()
	local store = call("openPanel", "StorePanel")
	log(string.format("magazin: %d rânduri", store.rows))
	check(store.rows >= 9, "magazinul nu listează permisele și produsele")
	task.wait(2.5) -- prețurile vin de la Roblox
	log("SNAP magazin")
	task.wait(1)
	call("closePanel", "StorePanel")
end)

step("3d. Darul Bunicii: fereastra seriei de 7 zile", function()
	call("daily")
	task.wait(1.2)
	log("SNAP darul-bunicii")
	task.wait(0.8)
	call("closePanel", "DailyPopup")
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
	-- noaptea începe la amurg (18,8) și înaintează spre zori (vezi SkyCycle.hourFor)
	check(seen.clock < 8.5 or seen.clock > 18.5, "lumina nu s-a schimbat (ClockTime " .. seen.clock .. ")")
	-- ambianța: noaptea greierii cântă, vântul se potolește
	local amb = call("ambience")
	log(
		string.format(
			"ambianță noaptea: greieri %.2f (țintă %.2f), vânt %.2f",
			amb.crickets or -1,
			amb.cricketsTarget or -1,
			amb.wind or -1
		)
	)
	check((amb.cricketsTarget or 0) > 0 and (amb.crickets or 0) > 0.05, "noaptea nu se aud greierii")
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
	-- Beciul: fiecare creatură (expusă sau ascunsă) cu miniatura ei 3D
	local cellar = call("openPanel", "CellarPanel")
	log(string.format("beciul: %d rânduri, %d previzualizări 3D", cellar.rows, cellar.previews))
	check(cellar.rows >= 2, "beciul nu listează creaturile")
	check(cellar.previews == cellar.rows, "nu toate rândurile beciului au creatura în 3D")
	task.wait(0.6)
	log("SNAP beci")
	task.wait(1)
	call("closePanel", "CellarPanel")
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
	-- Bunica sculptată are fața pictată în textură; cea veche (R15) are fața desenată 2D
	check(visuals.face or rig:GetAttribute("Sculpted") == true, "Bunica nu are fața desenată")
	check(
		((rig:GetAttribute("LineSeq") :: number?) or 0) > lineSeqBefore,
		"Bunica nu a spus nimic la lovitură"
	)
	local line = rig:GetAttribute("Line")
	check(
		type(line) == "string" and string.find(line, "bunica.hit", 1, true) ~= nil,
		"replica nu e de lovitură"
	)
	log(`vocea: {visuals.voice} încărcată={visuals.voiceLoaded} durata={visuals.voiceLength}`)
	check(visuals.voice ~= nil, "Bunica nu are vocea înregistrată la lovitură")
	check(visuals.voiceLoaded and visuals.voiceLength > 0.5, "vocea Bunicii nu s-a încărcat")
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

step("15d. „Bunica se supără”: pastila din HUD, sămânța exclusivă, ploaia de papuci", function()
	LiveEventService.forceStart("BunicaSeSupara", 40)
	local exclusive = ShopService.exclusive() :: string
	check(exclusive ~= nil, "evenimentul nu are sămânță exclusivă")
	check(
		waitFor(function()
			local seen = call("query")
			local pill = containsText(seen.hud, "fury") or containsText(seen.hud, "supără")
			return seen.shopStock[exclusive] == 1 and pill
		end, 5),
		"clientul nu vede evenimentul sau sămânța exclusivă"
	)
	task.wait(2)
	log("SNAP bunica-se-supara")
	LiveEventService.stop()
end)

step("15e. Muzica: atlasul se încarcă, straturile cântă sincron, efectele cad pe ritm", function()
	check(
		waitFor(function()
			return call("music").enabled
		end, 30),
		"dirijorul nu a pornit (atlasul audio nu s-a încărcat?)"
	)
	local info = call("music")
	local offsets = {}
	for name, layer in info.layers do
		check(layer.ready and layer.playing, "stratul " .. name .. " nu cântă")
		table.insert(offsets, layer.offset)
	end
	check(#offsets == 4, "lipsesc straturi: " .. #offsets)
	table.sort(offsets)
	check(
		offsets[#offsets] - offsets[1] < 0.1,
		"straturile nu sunt sincrone: " .. offsets[1] .. " … " .. offsets[#offsets]
	)
	DayNightService.forcePhase("Night")
	check(
		waitFor(function()
			local layers = call("music").layers
			return layers.noapte.volume > 0.8 and layers.zi.volume < 0.2
		end, 5),
		"noaptea nu a trecut pe stratul de noapte"
	)
	local cue = call("cue", "pleosc")
	check(
		cue.at ~= nil and cue.at >= cue.now and cue.at - cue.now < 0.2,
		"efectul nu s-a programat pe ritm: now=" .. tostring(cue.now) .. " at=" .. tostring(cue.at)
	)
	log(
		string.format(
			"muzică: decalaj maxim între straturi %.3f s; efect la +%.3f s",
			offsets[#offsets] - offsets[1],
			cue.at - cue.now
		)
	)
	DayNightService.forcePhase(nil)
end)

step("15b. Ecranul de încărcare (demonstrație: capturi și înregistrare video)", function()
	log("VIDEO incarcare")
	call("loading", "demo")
	for i = 1, 14 do
		log(string.format("SNAP incarcare-%02d", i))
		task.wait(0.9)
	end
	check(
		waitFor(function()
			return call("loading", "demoState").stage == "done"
		end, 10),
		"demonstrația ecranului de încărcare nu s-a terminat"
	)
	local state = call("loading", "state")
	check(not state.present, "ecranul de încărcare a rămas pe ecran")
	check(state.playerList and state.chat, "interfața Roblox n-a revenit după demonstrație")
end)

step("15f. Familie sau rivali: modul se schimbă doar ziua și ajunge la client", function()
	DayNightService.forcePhase("Night")
	check(not FamilyService.setMode(player, "Rival"), "modul s-a schimbat noaptea")
	DayNightService.forcePhase("Day")
	check(FamilyService.setMode(player, "Rival"), "modul nu s-a schimbat ziua")
	check(me.profile.familyMode == "Rival", "profilul nu a salvat modul")
	check(
		waitFor(function()
			return call("query").familyMode == "Rival"
		end, 3),
		"clientul nu vede modul Rival"
	)
	check(not FamilyService.setMode(player, "Family"), "modul s-a schimbat din nou fără pauză")
	task.wait(10.5)
	check(FamilyService.setMode(player, "Family"), "modul nu a revenit la Family")
end)

-- Pregătește un Epic expus acasă, fără scut și fără furturi în noaptea asta
local function epicAtHome(): string
	local record = Inventory.newRecord(me.profile, player.UserId, "Mamaligator", "Normal", nil)
	local where, key = Inventory.place(me.profile, record)
	check(where == "pedestal" and key, "nu e loc pe piedestal pentru Epic")
	CreatureService.renderKey(me, key :: string)
	me.shieldUntil = 0
	me.stolenTonight = 0
	return record.uid
end

step("15g. Un vecin hoț vine noaptea prin sat, ia Epicul și e doborât de papucul jucătorului", function()
	call("walkTo", me.plot.geometry.spawnCFrame.Position)
	DayNightService.forcePhase("Night")
	local uid = epicAtHome()
	local npc = NpcThiefService.freeNeighbour(me)
	check(npc, "niciun vecin liber")
	NpcThiefService.markActive(player)
	check(NpcThiefService.eligible(me), "jucătorul activ nu e țintă")
	local outcome: string? = nil
	task.spawn(function()
		outcome = NpcThiefService.attempt(me, npc)
	end)
	check(
		waitFor(function()
			return npc.actor ~= nil and RaidService.isCarrying(npc.actor)
		end, 60),
		"hoțul vecin nu a ajuns la creatură (pathfinding prin sat)"
	)
	check(RaidService.isCarried(uid), "hoțul a luat altă creatură decât Epicul")
	log("SNAP vecin-hot")
	check(
		waitFor(function()
			return table.find(call("query").notifications, "notify.NpcThiefComing") ~= nil
		end, 3),
		"jucătorul nu a fost avertizat"
	)
	call("throwAt", npc.name)
	check(
		waitFor(function()
			return outcome ~= nil
		end, 20),
		"încercarea nu s-a încheiat"
	)
	check(outcome == "Hit", "rezultat: " .. tostring(outcome))
	check(Inventory.findPedestal(me.profile, uid) ~= nil, "Epicul nu s-a întors acasă")
	check(
		waitFor(function()
			return npc.actor == nil
		end, 25),
		"hoțul nu a plecat"
	)
	check(npc.plot.owner == npc, "vecinul a fost înlocuit")
end)

step("15h. Fără papuc, vecinul duce Epicul acasă, iar jucătorul îl poate fura înapoi", function()
	epicAtHome()
	-- ținta e cea mai valoroasă creatură până la Epic (acasă poate fi și Epicul din pasul anterior)
	local targetKey = NpcThieves.pickTarget(me.profile.pedestals, RaidService.isCarried) :: string
	local uid = me.profile.pedestals[targetKey].uid
	local npc = NpcThiefService.freeNeighbour(me)
	check(npc, "niciun vecin liber")
	NpcThiefService.markActive(player)
	local outcome = NpcThiefService.attempt(me, npc)
	check(outcome == "Stolen", "rezultat: " .. tostring(outcome))
	local key = Inventory.findPedestal(npc.profile, uid)
	check(key, "Epicul nu e pe piedestalul vecinului")
	check(CreatureService.modelAt(npc, key :: string) ~= nil, "Epicul nu se vede la vecin")
	check(
		waitFor(function()
			return table.find(call("query").notifications, "notify.StealBack") ~= nil
		end, 3),
		"jucătorul nu a fost îndemnat să-l fure înapoi"
	)
	check(
		waitFor(function()
			return npc.actor == nil
		end, 25),
		"hoțul nu a plecat"
	)
	-- Furtul înapoi, pe căile reale: jucătorul merge la vecin și ține apăsat pe Epic. Bunica vecinului ar
	-- arunca papucul în jucătorul intrat noaptea în ograda ei (pasul 15 o pornește): aici verificăm doar furtul
	BunicaService.setEnabled(false)
	call("walkTo", roadPoint(me.plot))
	call("walkTo", roadPoint(npc.plot))
	-- intră pe poarta vecinului (pathfinding-ul agentului nu ocolește singur gardul până la poartă)
	local gate = npc.plot.geometry.cframe
	call("walkTo", (gate * CFrame.new(0, 3, -World.plotSize.Z / 2 - 6)).Position, 3)
	call("walkTo", (gate * CFrame.new(0, 3, -World.plotSize.Z / 2 + 5)).Position, 3)
	local distance = call("walkTo", approach(npc, key :: string))
	if distance >= 6 then
		-- piedestalul deblocat acum poate fi încadrat de alte creaturi: încearcă și dinspre casă
		local model = CreatureService.modelAt(npc, key :: string) :: Model
		local behind = model:GetPivot().Position - npc.plot.geometry.cframe.LookVector * 4.5
		distance = call("walkTo", Vector3.new(behind.X, npc.plot.geometry.cframe.Position.Y + 3, behind.Z))
	end
	if distance >= 6 then
		local model = CreatureService.modelAt(npc, key :: string) :: Model
		local position = call("query").position
		local localTarget = npc.plot.geometry.cframe:PointToObjectSpace(model:GetPivot().Position)
		local localMe = npc.plot.geometry.cframe:PointToObjectSpace(position)
		log(
			string.format(
				"blocat la furtul înapoi: piedestal %s la (%.0f, %.0f) în ogradă, jucătorul la (%.0f, %.0f)",
				key :: string,
				localTarget.X,
				localTarget.Z,
				localMe.X,
				localMe.Z
			)
		)
		call("lookAt", model:GetPivot().Position, position + Vector3.new(0, 25, 0), 1.5)
		task.wait(0.6)
		log("SNAP blocat-furt-inapoi")
	end
	check(distance < 6, "nu a ajuns la Epic (rămas " .. math.floor(distance) .. ")")
	local model = CreatureService.modelAt(npc, key :: string) :: Model
	local result = call("holdPrompt", "StealPrompt", npc.userId, model:GetPivot().Position)
	if result ~= "ok" then
		log(
			"server: modelul Epicului "
				.. model:GetFullName()
				.. ", prompt "
				.. tostring(model:FindFirstChildWhichIsA("ProximityPrompt", true))
		)
		for _, line in call("prompts", npc.userId, model:GetPivot().Position) do
			log("client: " .. line)
		end
	end
	check(result == "ok", "prompt de furt înapoi: " .. tostring(result))
	check(
		waitFor(function()
			return RaidService.isCarrying(myActor)
		end, 3),
		"furtul înapoi nu a început"
	)
	RaidService.drop(myActor)
	call("walkTo", roadPoint(npc.plot))
	call("walkTo", roadPoint(me.plot))
	DayNightService.forcePhase("Day")
end)

step("15i. Caietul Bunicii: colecția și treburile zilei, cu răsplata luată din Caiet", function()
	local collection = call("notebook", "collection")
	check(collection.notebook and collection.notebook.count >= 1, "colecția e goală")
	check(collection.rows >= #Creatures.list, "colecția nu listează creaturile (" .. collection.rows .. ")")
	check(table.find(call("query").notifications, "notify.Discovered") ~= nil, "nicio descoperire anunțată")
	task.wait(0.4)
	log("SNAP caiet-colectie")
	local quests = call("notebook", "quests")
	check(quests.rows >= 5, "treburile nu apar (" .. quests.rows .. " rânduri)")
	local first = me.profile.quests.list[1]
	first.progress = first.goal
	StateService.markDirty(player)
	local before = me.profile.lei
	call("fire", "Notebook", "claimQuest", 1)
	check(
		waitFor(function()
			return me.profile.quests.list[1].claimed
		end, 3),
		"răsplata treburii nu s-a luat"
	)
	check(me.profile.lei > before, "leii nu au crescut")
	check(
		waitFor(function()
			return table.find(call("query").notifications, "notify.QuestReward") ~= nil
		end, 3),
		"fără notificarea răsplății"
	)
	call("notebook", "quests")
	task.wait(0.4)
	log("SNAP caiet-treburi")
	call("closePanel", "NotebookPanel")
end)

step("15j. Schimb cu un vecin-bot: cererea, fereastra, ofertele, acceptarea, numărătoarea", function()
	DayNightService.forcePhase("Day")
	local plot = nearestNpcPlots(me.plot)[1]
	local traderBot = Actors.createBot("Negustor", plot.geometry.spawnCFrame)
	local trader = PlotService.assignBot(plot, traderBot)
	local gift = Inventory.newRecord(trader.profile, traderBot.id, "SarmalinaBallerina", "Big", "Wet")
	table.insert(trader.profile.cellar, gift)
	trader.profile.lei = 1000
	local mine = Inventory.newRecord(me.profile, player.UserId, "CeapaTurbo", "Normal", nil)
	table.insert(me.profile.cellar, mine)
	StateService.markDirty(player)
	local leiBefore = me.profile.lei
	check(TradeService.request(trader, me), "cererea botului a fost refuzată")
	check(
		waitFor(function()
			return call("trade").request
		end, 3),
		"cererea nu apare la jucător"
	)
	log("SNAP schimb-cerere")
	call("fire", "Trade", "respond", trader.userId, true)
	check(
		waitFor(function()
			return call("trade").window
		end, 3),
		"fereastra de schimb nu s-a deschis"
	)
	call("fire", "Trade", "offer", { mine.uid }, 0)
	TradeService.offer(trader, { gift.uid }, 250)
	check(
		waitFor(function()
			local view = call("trade")
			return view.theirsRows >= 2 and string.find(view.status, "Negustor") == nil
		end, 3),
		"oferta botului nu apare în fereastră"
	)
	task.wait(0.4)
	log("SNAP schimb-fereastra")
	TradeService.accept(trader)
	call("fire", "Trade", "accept")
	check(
		waitFor(function()
			return TradeService.confirmAt(me) ~= nil
		end, 3),
		"numărătoarea nu a pornit"
	)
	check(
		waitFor(function()
			return not TradeService.isTrading(me)
		end, 6),
		"schimbul nu s-a încheiat"
	)
	check(Inventory.findCellar(me.profile, gift.uid) ~= nil, "creatura primită lipsește din beci")
	check(Inventory.findCellar(trader.profile, mine.uid) ~= nil, "creatura dată n-a ajuns la bot")
	check(me.profile.lei >= leiBefore + 250, "leii din schimb nu au venit")
	check(
		me.profile.collection["SarmalinaBallerina:Wet"] == nil,
		"creatura primită la schimb a intrat în Caiet"
	)
	check(
		waitFor(function()
			return not call("trade").window
		end, 3),
		"fereastra a rămas deschisă"
	)
	Actors.removeBot(traderBot)
end)

step("15k. Gospodăria nouă: renașterea din Caiet", function()
	DayNightService.forcePhase("Day")
	me.profile.lei = 1e6
	StateService.markDirty(player)
	call("notebook", "rebirth")
	task.wait(0.4)
	log("SNAP caiet-renastere")
	call("fire", "Notebook", "rebirth")
	check(
		waitFor(function()
			return me.profile.rebirths == 1
		end, 3),
		"renașterea nu s-a făcut"
	)
	check(string.find(me.plot.geometry.sign.Text, "★", 1, true) ~= nil, "tăblița nu are steluța")
	check(count(me.profile.pedestals) == 1 and #me.profile.cellar == 0, "inventarul nu s-a golit corect")
	check(
		waitFor(function()
			return call("query").pedestals == 1
		end, 3),
		"clientul nu vede gospodăria nouă"
	)
	call("closePanel", "NotebookPanel")
end)

-- Telefoane emulate (puncte GUI, landscape, fără bara Roblox): Root micșorat, HUD-ul în modul tactil
local PHONES = {
	{ name = "iPhone-SE", w = 667, h = 339 },
	{ name = "Android-mic", w = 740, h = 324 },
	{ name = "Android-lat", w = 800, h = 354 },
}

local function overlaps(a: any, b: any): boolean
	return a.x < b.x + b.w - 0.5 and b.x < a.x + a.w - 0.5 and a.y < b.y + b.h - 0.5 and b.y < a.y + a.h - 0.5
end

step(
	"15l. Telefonul: nimic peste săritură sau joystick, totul în ecran, butoane de deget, text lizibil",
	function()
		DayNightService.forcePhase("Day")
		call("walkTo", me.plot.geometry.spawnCFrame.Position)
		local real = call("phone").size
		log(string.format("ecranul real din Studio: %.0f×%.0f", real.X, real.Y))
		for _, phone in PHONES do
			if phone.w > real.X or phone.h > real.Y then
				log("sar peste " .. phone.name .. ": nu încape în fereastra Studio")
				continue
			end
			local report = call("phone", phone.w, phone.h)
			local layout = report.layout
			check(layout ~= nil, phone.name .. ": modul tactil nu s-a aplicat")
			check(
				#report.buttons >= 8,
				phone.name .. ": prea puține butoane în audit (" .. #report.buttons .. ")"
			)
			for i, a in report.buttons do
				local short = string.match(a.name, "[^.]+%.[^.]+$") or a.name
				check(
					a.x >= -0.5 and a.y >= -0.5 and a.x + a.w <= phone.w + 0.5 and a.y + a.h <= phone.h + 0.5,
					phone.name .. ": în afara ecranului: " .. short
				)
				check(not overlaps(a, layout.jump), phone.name .. ": peste săritură: " .. short)
				check(not overlaps(a, layout.thumb), phone.name .. ": în zona joystick-ului: " .. short)
				check(
					math.min(a.w, a.h) >= 44 or string.find(a.name, "SeedBar", 1, true) ~= nil,
					string.format("%s: buton prea mic (%.0f×%.0f): %s", phone.name, a.w, a.h, short)
				)
				for j = i + 1, #report.buttons do
					local b = report.buttons[j]
					local nested = string.find(b.name, a.name, 1, true)
						or string.find(a.name, b.name, 1, true)
					check(
						nested or not overlaps(a, b),
						phone.name .. ": se suprapun " .. short .. " și " .. b.name
					)
				end
			end
			check(#report.small == 0, phone.name .. ": text prea mic: " .. table.concat(report.small, " | "))
			log(string.format("%s: %d butoane verificate", phone.name, #report.buttons))
			task.wait(0.4)
			log("SNAP telefon-" .. phone.name)
			call("phoneMenu")
			task.wait(0.5)
			log("SNAP telefon-meniu-" .. phone.name)
			call("phoneMenu")
		end
		-- rafala de mesaje pe telefon: un singur mesaj odată, urgentul primul și unit (×3), confirmările ascunse,
		-- totul în capsulă (sus, deasupra zonei joystick-ului)
		call("phone", PHONES[1].w, PHONES[1].h)
		local burst = call("noticeBurst", 0.3)
		local capsule = burst.capsule
		check(capsule.visible and #capsule.showing == 1, "capsula arată " .. #capsule.showing .. " mesaje")
		check(
			string.find(capsule.showing[1], "×3", 1, true) ~= nil,
			"alarma nu e prima sau nu e unită: " .. capsule.showing[1]
		)
		local layout = call("phone", PHONES[1].w, PHONES[1].h).layout
		local rect = capsule.rects[1]
		check(
			rect.y >= layout.notice.y - 1 and rect.y + rect.h <= layout.thumb.y + 1,
			string.format("capsula iese din locul ei (y %.0f, h %.0f)", rect.y, rect.h)
		)
		local burst2 = call("noticeBurst", 0.3)
		check(#burst2.capsule.showing == 1, "a doua rafală: mai multe mesaje pe ecran")
		check(burst2.capsule.waiting <= 6, "coada a crescut fără limită: " .. burst2.capsule.waiting)
		log("SNAP telefon-mesaje")
		-- coada se golește singură: mesajele se scurtează când așteaptă multe, iar indiciile și ambientul expiră
		local started = os.clock()
		check(
			waitFor(function()
				local state = call("notices").capsule
				return #state.showing == 0 and state.waiting == 0
			end, 40),
			"capsula nu s-a golit"
		)
		log(string.format("două rafale golite în %.0f s", os.clock() - started))
		-- un panou pe telefon: aproape tot ecranul
		call("phone", PHONES[1].w, PHONES[1].h)
		local shop = call("openPanel", "ShopPanel")
		check(shop.rows >= 1, "taraba nu listează nimic pe telefon")
		task.wait(0.5)
		log("SNAP telefon-taraba")
		call("closePanel", "ShopPanel")
		DayNightService.forcePhase("Night")
		task.wait(1)
		log("SNAP telefon-noapte")
		DayNightService.forcePhase("Day")
		call("phone")
	end
)

step("15m. Casa: acoperișul de jos, sub streașină, din colț și de sus", function()
	DayNightService.forcePhase("Day")
	local cf = me.plot.geometry.cframe
	local house = cf * CFrame.new(0, 0, World.plotSize.Z / 2 - 9)
	photograph(
		"casa-streasina",
		(house * CFrame.new(0, 8, -6)).Position,
		(house * CFrame.new(4, 2.6, -12)).Position
	)
	photograph("casa-colt", (house * CFrame.new(0, 8, 0)).Position, (house * CFrame.new(14, 3, -14)).Position)
	photograph("casa-sus", (house * CFrame.new(0, 9, 0)).Position, (house * CFrame.new(10, 22, -16)).Position)
	local art = me.plot.geometry.model:FindFirstChild("world.Casa")
	check(art ~= nil, "casa sculptată nu e în ogradă")
	local parts = {}
	for _, child in (art :: Instance):GetChildren() do
		if child:IsA("MeshPart") then
			table.insert(parts, child.Name)
		end
	end
	table.sort(parts)
	check(table.concat(parts, ",") == "body,roof,trim", "piesele casei: " .. table.concat(parts, ","))
end)

step("15n. Inima din beci: o creatură de suflet nu poate fi furată", function()
	local record = me.profile.pedestals[firstPedestal(me) :: string] or me.profile.cellar[1]
	check(record, "nicio creatură pentru inimă")
	call("fire", "SetSoul", record.uid, true)
	check(
		waitFor(function()
			return record.soul == true
		end, 3),
		"inima nu s-a pus"
	)
	local cellar = call("openPanel", "CellarPanel")
	check(cellar.rows >= 1, "beciul e gol")
	task.wait(0.5)
	log("SNAP beci-suflet")
	call("closePanel", "CellarPanel")
	call("fire", "SetSoul", record.uid, false)
end)

step("16. Fără erori de script (server și client)", function()
	local serverErrors = {}
	for _, entry in LogService:GetLogHistory() do
		if
			entry.messageType == Enum.MessageType.MessageError
			and not string.find(entry.message, "PLAYTEST", 1, true)
			-- Studio (doar în sesiunea locală) împachetează texturile modelelor și poate primi 429: nu e o eroare
			-- a jocului și nu apare pe serverele reale
			and not string.find(entry.message, "Failed to upload TexturePack", 1, true)
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
