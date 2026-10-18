--!strict
-- Cadrul mini-jocurilor: înscrierea la loc, numărătoarea, scorul, plecarea în mijlocul rundei, răsplata o
-- singură dată și curățenia de la final.

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Village = require(Shared.Config.Village)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local Busy = (require :: any)(ServerScriptService.Server:WaitForChild("Busy"))
	local PlotService = services.PlotService
	local Service = services.MinigameService

	local DEF = {
		id = "TestJoc",
		minPlayers = 2,
		maxPlayers = 8,
		durationSeconds = 30,
		site = "centru",
		ages = "",
		rewards = { participation = 20, placements = { 30, 20, 10 } },
	}
	local finished = 0
	local MODULE = {
		setup = function(match: any)
			local prop = Instance.new("Part")
			prop.Anchored = true
			prop.Parent = match.folder
		end,
		action = function(match: any, owner: any, payload: any)
			if payload == "punct" then
				match.score(owner, 1)
			end
		end,
		finish = function(match: any)
			finished += 1
			return match.scores
		end,
	}

	local function bot(name: string, index: number): (any, any)
		local actor = Actors.createBot(name, PlotService.plots[index].geometry.spawnCFrame)
		local owner = PlotService.assignBot(PlotService.plots[index], actor);
		(Actors.characterOf(actor) :: Model):PivotTo(CFrame.new(Village.hub + Vector3.new(index * 3, 3, 20)))
		return actor, owner
	end

	describe("Mini-jocurile", function()
		it(
			"doi boți intră, unul pleacă la mijloc; cel rămas ia răsplata o dată, iar locul rămâne curat",
			function()
				Service.register(DEF, MODULE)
				local a, ownerA = bot("JucatorA", 6)
				local b, ownerB = bot("JucatorB", 7)
				expect(Service.open("TestJoc", 30)).toBe(true)
				expect(Service.open("TestJoc", 30)).toBe(false) -- locul e ocupat
				expect(Service.join(ownerA, "TestJoc")).toBe(true)
				expect(Service.join(ownerB, "TestJoc")).toBe(true)
				Service.closeEnrollment("centru")
				expect(Spec.waitFor(function()
					return Service.matchAt("centru") ~= nil
				end, 2)).toBe(true)
				local match = Service.matchAt("centru")
				expect(Busy.is(a) and Busy.is(b)).toBe(true)
				task.wait(3.2) -- numărătoarea 3-2-1
				Service.act(ownerA, "punct")
				Service.act(ownerA, "punct")
				Service.act(ownerB, "punct")
				expect(match.scores[ownerA.userId]).toBe(2)
				Actors.removeBot(b) -- pleacă în mijlocul rundei
				local before = ownerA.profile.lei
				local folder = match.folder
				Service.stop("centru")
				expect(finished).toBe(1)
				expect(ownerA.profile.lei - before).toBe(
					DEF.rewards.participation + DEF.rewards.placements[1]
				)
				expect(folder.Parent == nil).toBe(true)
				expect(Workspace:FindFirstChild("Minigame_TestJoc") == nil).toBe(true)
				expect(Busy.is(a)).toBe(false)
				-- a doua oprire nu mai dă nimic
				Service.stop("centru")
				expect(finished).toBe(1)
				expect(ownerA.profile.lei - before).toBe(
					DEF.rewards.participation + DEF.rewards.placements[1]
				)
				Actors.removeBot(a)
			end
		)

		it("departe de loc nu te poți înscrie; prea puțini jucători anulează runda", function()
			local a, ownerA = bot("Singur", 6)
			expect(Service.open("TestJoc", 30)).toBe(true);
			(Actors.characterOf(a) :: Model):PivotTo(PlotService.plots[1].geometry.spawnCFrame)
			expect(Service.join(ownerA, "TestJoc")).toBe(false);
			(Actors.characterOf(a) :: Model):PivotTo(CFrame.new(Village.hub + Vector3.new(5, 3, 20)))
			expect(Service.join(ownerA, "TestJoc")).toBe(true)
			Service.closeEnrollment("centru")
			task.wait(0.5)
			expect(Service.matchAt("centru") == nil).toBe(true) -- un singur jucător: anulat
			expect(Busy.is(a)).toBe(false)
			Actors.removeBot(a)
		end)

		local function play(id: string, owners: { any })
			expect(Service.open(id, 30)).toBe(true)
			for _, owner in owners do
				expect(Service.join(owner, id)).toBe(true)
			end
			local site = require(game:GetService("ReplicatedStorage").Shared.Config.Minigames).byId[id].site
			Service.closeEnrollment(site)
			expect(Spec.waitFor(function()
				return Service.matchAt(site) ~= nil
			end, 2)).toBe(true)
			task.wait(3.2)
			return Service.matchAt(site), site
		end

		local function near(actor: any, site: string, offset: Vector3)
			local Layout = require(game:GetService("ReplicatedStorage").Shared.Domain.VillageLayout)
			local cf = Layout.build().sites[site];
			(Actors.characterOf(actor) :: Model):PivotTo(
				CFrame.new(cf.Position + offset + Vector3.new(0, 3, 0))
			)
		end

		it("Prinde cocoșul: atingerea îl prinde (1 punct) și cocoșul reapare", function()
			local Cocos = (require :: any)(ServerScriptService.Server.Minigames.Cocos)
			local a, ownerA = bot("Prinzator", 6)
			local b, ownerB = bot("Alergator", 7)
			local match = play("Cocos", { ownerA, ownerB })
			local rooster = Cocos.rooster(match);
			(Actors.characterOf(a) :: Model):PivotTo(rooster:GetPivot() + Vector3.new(0, 3, 0))
			expect(Spec.waitFor(function()
				return (match.scores[ownerA.userId] or 0) >= 1
			end, 2)).toBe(true)
			Service.stop("centru")
			Actors.removeBot(a)
			Actors.removeBot(b)
		end)

		it(
			"Șotronul: pașii în ordine dau tura; o greșeală oprește runda; recordul ajunge pe avizier",
			function()
				local Sotron = (require :: any)(ServerScriptService.Server.Minigames.Sotron)
				local a, ownerA = bot("Sarator", 6)
				near(a, "magazin", Vector3.new(0, 0, 5))
				local match = play("Sotron", { ownerA })
				local character = Actors.characterOf(a) :: Model
				local function stepOn(i: number)
					local square = match.folder:FindFirstChild("Patrat" .. i) :: BasePart
					character:PivotTo(CFrame.new(square.Position + Vector3.new(0, 3, 0)))
					task.wait(0.3)
					character:PivotTo(CFrame.new(match.arena.Position + Vector3.new(0, 3, 0))) -- departe de pătrate
					task.wait(0.3)
				end
				for _ = 1, 2 do
					local seq = table.clone(Sotron.sequence(match))
					Spec.waitFor(function()
						return os.clock() >= match.data.showUntil
					end, 5)
					for _, i in seq do
						stepOn(i :: number)
					end
				end
				expect(match.scores[ownerA.userId]).toBe(2)
				Spec.waitFor(function()
					return os.clock() >= match.data.showUntil
				end, 5)
				local first = Sotron.sequence(match)[1] :: number
				local wrong = (first % (Sotron.SQUARES :: number)) + 1
				stepOn(wrong)
				expect(Spec.waitFor(function()
					return Service.matchAt("magazin") == nil
				end, 2)).toBe(true)
				expect(ownerA.profile.records.Sotron).toBe(2)
				Actors.removeBot(a)
			end
		)

		it(
			"Ciocnitul ouălor: trei ciocniri, ouăle crăpate trec la câștigător (niciun ou nu se pierde)",
			function()
				local a, ownerA = bot("Ou1", 6)
				local b, ownerB = bot("Ou2", 7)
				near(a, "bucatarie", Vector3.new(3, 0, 0))
				near(b, "bucatarie", Vector3.new(-3, 0, 0))
				ownerA.profile.eggs = { Rosu = 3 }
				ownerB.profile.eggs = { Alb = 3 }
				local match = play("Oua", { ownerA, ownerB })
				Service.act(ownerA, { choice = "Rosu" })
				Service.act(ownerB, { choice = "Alb" })
				expect(Spec.waitFor(function()
					return Service.matchAt("bucatarie") == nil
				end, 20)).toBe(true)
				local total = 0
				for _, owner in { ownerA, ownerB } do
					for _, n in owner.profile.eggs do
						total += n
					end
				end
				expect(total).toBe(6)
				local _ = match
				Actors.removeBot(a)
				Actors.removeBot(b)
			end
		)

		it("Oina: cursa completă dă punctul echipei; papucul de la prindere scoate alergătorul", function()
			local Oina = (require :: any)(ServerScriptService.Server.Minigames.Oina)
			local SlipperService = services.SlipperService
			local bots, owners = {}, {}
			for i = 1, 4 do
				local actor, owner = bot("Oina" .. i, i + 4 > 8 and i or i + 4)
				near(actor, "terenScoala", Vector3.new(i * 2, 0, 0))
				table.insert(bots, actor)
				table.insert(owners, owner)
			end
			local match = play("Oina", owners)
			local state = Oina.state(match)
			expect(state.batting).toBe("A")
			-- A = jucătorii 1 și 3 (pe rând); 1 lovește și aleargă
			local runner = owners[1]
			local character = Actors.characterOf(bots[1]) :: Model
			character:PivotTo(CFrame.new(match.data.start + Vector3.new(0, 3, 0)))
			task.wait(0.2)
			Service.act(runner, { bat = true })
			expect(match.data.running[runner] ~= nil).toBe(true)
			character:PivotTo(CFrame.new(match.data.finish + Vector3.new(0, 3, 0)))
			task.wait(0.4)
			character:PivotTo(CFrame.new(match.data.start + Vector3.new(0, 3, 0)))
			expect(Spec.waitFor(function()
				return state.points.A == 1
			end, 2)).toBe(true)
			-- 3 lovește; 2 (de la prindere) îl țintește
			local second = owners[3]
			local c3 = Actors.characterOf(bots[3]) :: Model
			c3:PivotTo(CFrame.new(match.data.start + Vector3.new(0, 3, 0)))
			task.wait(0.2)
			Service.act(second, { bat = true })
			local deadline = os.clock() + 10
			while not state.out[second.userId] and os.clock() < deadline do
				local at = (Actors.root(bots[3]) :: BasePart).Position;
				(Actors.characterOf(bots[2]) :: Model):PivotTo(CFrame.new(at + Vector3.new(9, 0, 0)))
				task.wait(0.1)
				SlipperService.throwAs(bots[2], at, "Slipper")
				task.wait(0.7)
			end
			expect(state.out[second.userId] == true or state.batting == "B").toBe(true)
			Service.stop("terenScoala")
			for _, actor in bots do
				Actors.removeBot(actor)
			end
		end)

		it("Ascunselea: Bunica atinge un ascuns și îl prinde; cel neprins ia punctele timpului", function()
			local Asc = (require :: any)(ServerScriptService.Server.Minigames.Ascunselea)
			local bots, owners = {}, {}
			for i = 1, 3 do
				local actor, owner = bot("Ascuns" .. i, i + 5)
				near(actor, "lanPorumb", Vector3.new(i * 3, 0, -25))
				table.insert(bots, actor)
				table.insert(owners, owner)
			end
			local match = play("Ascunselea", owners)
			match.data.hideUntil = workspace:GetServerTimeNow() -- testul nu așteaptă cele 20 s
			local seeker = Asc.seeker(match)
			local hider = if owners[1] == seeker then owners[2] else owners[1]
			local hiderRoot = (Actors.root(hider.actor) :: BasePart).Position;
			(Actors.characterOf(seeker.actor) :: Model):PivotTo(CFrame.new(hiderRoot + Vector3.new(1, 0, 0)))
			local caught = Spec.waitFor(function()
				return match.isGhost(hider)
			end, 3)
			if not caught then
				local sr = Actors.root(seeker.actor) :: BasePart
				local hr = Actors.root(hider.actor) :: BasePart
				print(
					"[e2e] ascunselea:",
					sr and sr.Position,
					hr and hr.Position,
					match.data.hideUntil - workspace:GetServerTimeNow(),
					seeker.userId,
					hider.userId
				)
			end
			expect(caught).toBe(true)
			expect(match.scores[seeker.userId] >= 3).toBe(true)
			Service.stop("lanPorumb")
			for _, actor in bots do
				Actors.removeBot(actor)
			end
		end)

		it(
			"Păcală: ascunșii devin obiecte; papucul căutătorului îl prinde pe Păcală; râsul aduce puncte",
			function()
				local Pacala = (require :: any)(ServerScriptService.Server.Minigames.Pacala)
				local SlipperService = services.SlipperService
				local bots, owners = {}, {}
				for i = 1, 4 do
					local actor, owner = bot("Pacala" .. i, i + 4)
					near(actor, "claie", Vector3.new(i * 5 - 12, 0, -20))
					table.insert(bots, actor)
					table.insert(owners, owner)
				end
				local match = play("Pacala", owners)
				match.data.hideUntil = workspace:GetServerTimeNow()
				local seeker, seekerBot
				local hiders = {}
				for i, owner in owners do
					if match.data.seekers[owner] then
						seeker, seekerBot = owner, bots[i]
					else
						table.insert(hiders, { owner = owner, actor = bots[i] })
					end
				end
				expect(seeker ~= nil).toBe(true)
				expect(Pacala.isDisguised(match, hiders[1].owner)).toBe(true)
				-- râsul
				Service.act(hiders[2].owner, { laugh = true })
				expect(match.scores[hiders[2].owner.userId] >= 2).toBe(true)
				-- prinderea
				local target = hiders[1]
				-- momelile de lângă Păcală se scot, ca testul să nu depindă de unde au căzut
				local around = (Actors.root(target.actor) :: BasePart).Position
				for _, child in match.folder:GetChildren() do
					if
						child.Name == "Momeala"
						and child:IsA("Model")
						and (child:GetPivot().Position - around).Magnitude < 10
					then
						child:Destroy()
					end
				end
				local deadline = os.clock() + 16
				while Pacala.isDisguised(match, target.owner) and os.clock() < deadline do
					local at = (Actors.root(target.actor) :: BasePart).Position;
					(Actors.characterOf(seekerBot) :: Model):PivotTo(CFrame.new(at + Vector3.new(4, 0, 0)))
					task.wait(0.1)
					SlipperService.throwAs(seekerBot, at, "Slipper")
					task.wait(0.7)
				end
				expect(Pacala.isDisguised(match, target.owner)).toBe(false)
				expect(match.scores[seeker.userId] >= 3).toBe(true)
				Service.stop("claie")
				for _, actor in bots do
					Actors.removeBot(actor)
				end
			end
		)

		it(
			"Cursa cu roaba: porțile în ordine; scurtătura te întoarce la ultima poartă; ordinea la sosire",
			function()
				local Roaba = (require :: any)(ServerScriptService.Server.Minigames.Roaba)
				local a, ownerA = bot("Roaba1", 6)
				local b, ownerB = bot("Roaba2", 7)
				near(a, "biserica", Vector3.new(0, 0, -20))
				near(b, "biserica", Vector3.new(3, 0, -20))
				local match = play("Roaba", { ownerA, ownerB })
				local gates = Roaba.gates(match)
				local run = match.data.runs[ownerA]
				local character = Actors.characterOf(a) :: Model
				-- scurtătura: direct la poarta 4 imediat
				character:PivotTo(CFrame.new(gates[3] + Vector3.new(0, 3, 0)))
				task.wait(0.3)
				expect(run.next <= 3).toBe(true)
				-- pe rând, cu timp între porți
				for i = run.next, #gates do
					task.wait(1.2)
					character:PivotTo(CFrame.new(gates[i] + Vector3.new(0, 3, 0)))
					task.wait(0.3)
				end
				expect(Spec.waitFor(function()
					return run.finishedAt ~= nil
				end, 3)).toBe(true)
				expect(match.data.finishOrder[1]).toBe(ownerA)
				Service.stop("biserica")
				Actors.removeBot(a)
				Actors.removeBot(b)
			end
		)

		it(
			"Obby-ul morii: treptele în ordine, căderea te pune înapoi pe ultima, sosirea dă recordul",
			function()
				local Moara = (require :: any)(ServerScriptService.Server.Minigames.Moara)
				local a, ownerA = bot("Obby", 6)
				near(a, "moara", Vector3.new(0, 0, -10))
				local match = play("Moara", { ownerA })
				local gates = Moara.gates(match)
				local run = match.data.runs[ownerA]
				local character = Actors.characterOf(a) :: Model
				task.wait(1) -- de la start la prima treaptă: nu e o scurtătură
				for i = 2, 5 do
					character:PivotTo(CFrame.new(gates[i] + Vector3.new(0, 3, 0)))
					task.wait(0.6)
				end
				expect(run.next).toBe(6)
				-- cade
				character:PivotTo(CFrame.new(gates[5] - Vector3.new(0, 20, 0)))
				task.wait(0.5)
				local root = Actors.root(a) :: BasePart
				expect(root.Position.Y > gates[5].Y - 9).toBe(true)
				for i = 6, #gates do
					character:PivotTo(CFrame.new(gates[i] + Vector3.new(0, 3, 0)))
					task.wait(0.6)
				end
				expect(Spec.waitFor(function()
					return Service.matchAt("moara") == nil
				end, 3)).toBe(true)
				expect((ownerA.profile.records.Moara or 0) > 0).toBe(true)
				Actors.removeBot(a)
			end
		)

		it("Struguri: apăsările pe bătaie dau puncte (Perfect = 3), o bătaie se ia o dată", function()
			local Struguri = (require :: any)(ServerScriptService.Server.Minigames.Struguri)
			local a, ownerA = bot("Strugurar", 6)
			local b, ownerB = bot("Strugurar2", 7)
			near(a, "via", Vector3.new(0, 0, -12))
			near(b, "via", Vector3.new(3, 0, -12))
			local match = play("Struguri", { ownerA, ownerB })
			local beats = Struguri.beats(match)
			for i = 1, 4 do
				local at = match.startedAt + beats[i]
				Spec.waitFor(function()
					return workspace:GetServerTimeNow() >= at
				end, 5)
				Service.act(ownerA, { press = at })
				Service.act(ownerA, { press = at }) -- a doua oară: nimic
			end
			expect(match.scores[ownerA.userId]).toBe(12)
			Service.stop("via")
			Actors.removeBot(a)
			Actors.removeBot(b)
		end)

		it(
			"Discoteca: votul cu inimi; nu te votezi singur și nu votezi de două ori același concurent",
			function()
				local Disco = (require :: any)(ServerScriptService.Server.Minigames.Discoteca)
				local bots, owners = {}, {}
				for i = 1, 3 do
					local actor, owner = bot("Dansator" .. i, i + 5)
					near(actor, "discoteca", Vector3.new(i * 2, 0, 0))
					table.insert(bots, actor)
					table.insert(owners, owner)
				end
				local match = play("Discoteca", owners)
				match.data.voteAt = workspace:GetServerTimeNow() -- testul trece direct la vot
				expect(Spec.waitFor(function()
					return Disco.phase(match) == "vote"
				end, 2)).toBe(true)
				local a, b, c = owners[1], owners[2], owners[3]
				Service.act(a, { choice = tostring(a.userId) .. ":3" }) -- pe sine: refuzat
				Service.act(a, { choice = tostring(b.userId) .. ":3" })
				Service.act(a, { choice = tostring(b.userId) .. ":1" }) -- a doua oară: refuzat
				Service.act(c, { choice = tostring(b.userId) .. ":2" })
				Service.act(b, { choice = tostring(c.userId) .. ":1" })
				expect(match.scores[a.userId] or 0).toBe(0)
				expect(match.scores[b.userId]).toBe(5)
				expect(match.scores[c.userId]).toBe(1)
				Service.stop("discoteca")
				for _, actor in bots do
					Actors.removeBot(actor)
				end
			end
		)

		it("Hora pe ritm: cercul perfect (4 pași buni la rând pentru toți) cheamă Curcubeul", function()
			local HoraService = services.HoraService
			local GameState = require(game:GetService("ReplicatedStorage").Shared.GameState)
			local Hora = require(game:GetService("ReplicatedStorage").Shared.Config.Hora)
			HoraService.resetCooldown()
			local dancers = {}
			for i = 1, 3 do
				local angle = i * 2.1
				local actor = Actors.createBot(
					"Horist" .. i,
					CFrame.new(Hora.center + Vector3.new(math.cos(angle) * 5, 3, math.sin(angle) * 5))
				)
				table.insert(dancers, actor)
			end
			task.wait(0.3)
			for _, actor in dancers do
				HoraService.setDancing(actor, 30)
			end
			for _ = 1, 4 do
				local beat = math.ceil(workspace:GetServerTimeNow() / 0.5) * 0.5
				Spec.waitFor(function()
					return workspace:GetServerTimeNow() >= beat
				end, 2)
				for _, actor in dancers do
					HoraService.step(actor, beat)
				end
			end
			for _, actor in dancers do
				expect(HoraService.streak(actor) >= 4).toBe(true)
			end
			expect(Spec.waitFor(function()
				return GameState.get("Weather") == "Rainbow"
			end, 8)).toBe(true)
			for _, actor in dancers do
				Actors.removeBot(actor)
			end
		end)

		it(
			"Plăcintăria: aluat, umplutura comenzii, cuptorul (3 s), livrarea dau punctul echipei și creșterea mai rapidă",
			function()
				local Placinte = (require :: any)(ServerScriptService.Server.Minigames.Placinte)
				local GardenService = services.GardenService
				local a, ownerA = bot("Bucatar1", 6)
				local b, ownerB = bot("Bucatar2", 7)
				near(a, "bucatarie", Vector3.new(0, 0, -5))
				near(b, "bucatarie", Vector3.new(3, 0, -5))
				local match = play("Placinte", { ownerA, ownerB })
				local order = match.data.orders[1]
				local character = Actors.characterOf(a) :: Model
				local function at(id: string)
					character:PivotTo(CFrame.new(Placinte.station(match, id) + Vector3.new(0, 3, 2)))
					task.wait(0.15)
					Service.act(ownerA, { station = id })
				end
				at("Aluat")
				at(order)
				at("Cuptor")
				task.wait(Placinte.BAKE_SECONDS + 0.2)
				at("Cuptor")
				at("Livrare")
				expect(match.data.delivered).toBe(1)
				expect(match.scores[ownerB.userId]).toBe(1) -- punctul e al echipei
				expect(GardenService.boostFactor(ownerA)).toBe(Placinte.BOOST_FACTOR)
				Service.stop("bucatarie")
				Actors.removeBot(a)
				Actors.removeBot(b)
			end
		)

		it(
			"Ostașii: trecerea rapidă printre doi rupe lanțul și aduce un jucător în echipa alergătorului",
			function()
				local Ostasi = (require :: any)(ServerScriptService.Server.Minigames.Ostasi)
				local bots, owners = {}, {}
				for i = 1, 4 do
					local actor, owner = bot("Ostas" .. i, i + 4)
					near(actor, "terenScoala", Vector3.new(i * 2, 0, 0))
					table.insert(bots, actor)
					table.insert(owners, owner)
				end
				local match = play("Ostasi", owners)
				local runner = match.data.runner
				local calling = match.data.calling
				local runnerTeam = match.data.team[runner]
				local before = 0
				for _, team in match.data.team do
					if team == runnerTeam then
						before += 1
					end
				end
				local link = Ostasi.links(match, calling)[1]
				local pa = (Actors.root(link[1].actor) :: BasePart).Position
				local pb = (Actors.root(link[2].actor) :: BasePart).Position
				local mid = (pa + pb) / 2
				local normal = Vector3.new(-(pb - pa).Z, 0, (pb - pa).X).Unit
				local character = Actors.characterOf(runner.actor) :: Model
				character:PivotTo(CFrame.new(mid + normal * 3))
				task.wait(0.25)
				character:PivotTo(CFrame.new(mid - normal * 3)) -- 6 studs într-un pas de 0,1 s: viteză mare
				expect(Spec.waitFor(function()
					return match.data.runner ~= runner
				end, 2)).toBe(true)
				local after = 0
				for _, team in match.data.team do
					if team == runnerTeam then
						after += 1
					end
				end
				expect(after).toBe(before + 1)
				Service.stop("terenScoala")
				for _, actor in bots do
					Actors.removeBot(actor)
				end
			end
		)
	end)
end
