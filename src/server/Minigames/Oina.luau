--!strict
-- Oina cu papuci (2v2 până la 4v4, 3 minute, terenul școlii). Reguli în Domain/Oina. Cine e la bătaie stă
-- lângă linia de bătaie și „lovește” (acțiunea { bat = true }): mingea zboară, iar el aleargă pe culoar până la
-- capăt și înapoi. Cei de la prindere îl țintesc cu papucul (aruncarea obișnuită: în joc, papucul lovește
-- doar alergătorii). Schimb la jumătate sau când toți de la bătaie sunt scoși.

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local OinaRules = require(Shared.Domain.Oina)
local Minigame = require(Shared.Domain.Minigame)
local Kit = require(script.Parent.Parent.Happenings.Kit)
local Actors = require(script.Parent.Parent.Actors)
local PlotService = require(script.Parent.Parent.Services.PlotService)
local SlipperService = require(script.Parent.Parent.Services.SlipperService)

local Oina = {}

local REACH = 7

local function lane(match: any): (Vector3, Vector3)
	local sites = workspace:FindFirstChild("Village") and workspace.Village:FindFirstChild("Sites")
	local teren = sites and sites:FindFirstChild("terenScoala")
	local culoar = teren and teren:FindFirstChild("Culoar", true)
	local a = if culoar then culoar:GetAttribute("Start") else nil
	local b = if culoar then culoar:GetAttribute("End") else nil
	local start = match.arena * (if typeof(a) == "Vector3" then a else Vector3.new(-27, 0, 15))
	local finish = match.arena * (if typeof(b) == "Vector3" then b else Vector3.new(27, 0, 15))
	return start, finish
end

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function publish(match: any)
	local state = match.data.state
	local ghosts = {}
	for owner in match.ghosts do
		table.insert(ghosts, owner.userId)
	end
	local teams = {}
	for id, team in state.team do
		teams[tostring(id)] = team
	end
	match.publish({ points = state.points, batting = state.batting, teams = teams, ghosts = ghosts })
end

local function stopRunner(match: any, owner: any)
	local run = match.data.running[owner]
	if run then
		SlipperService.unregisterTarget(run.model)
		match.data.running[owner] = nil
	end
end

local function swap(match: any)
	for owner in match.data.running do
		stopRunner(match, owner)
	end
	OinaRules.swap(match.data.state)
	table.clear(match.ghosts) -- la schimb, cei scoși revin
	match.data.swapped = true
	publish(match)
end

function Oina.setup(match: any)
	local ids = {}
	for _, owner in match.players do
		table.insert(ids, owner.userId)
	end
	match.data.state = OinaRules.new(ids)
	match.data.running = {}
	match.data.start, match.data.finish = lane(match)
	match.data.byId = {}
	for _, owner in match.players do
		match.data.byId[owner.userId] = owner
	end
	publish(match)
end

function Oina.teamOf(match: any, owner: any): string
	return match.data.state.team[owner.userId] or "A"
end

function Oina.state(match: any): any
	return match.data.state
end

local function throwBall(match: any, from: Vector3, toward: Vector3)
	local ball = Instance.new("Part")
	ball.Name = "Minge"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(1.2, 1.2, 1.2)
	ball.Color = Color3.fromRGB(230, 60, 50)
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.Position = from + Vector3.new(0, 3, 0)
	ball.Parent = match.folder
	local tween =
		TweenService:Create(ball, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = from + (toward - from).Unit * 40 + Vector3.new(0, 1, 0),
		})
	tween:Play()
	task.delay(4, function()
		ball:Destroy()
	end)
end

function Oina.action(match: any, owner: any, payload: any)
	if typeof(payload) ~= "table" or payload.bat ~= true then
		return
	end
	local state = match.data.state
	if state.team[owner.userId] ~= state.batting or state.out[owner.userId] or match.data.running[owner] then
		return
	end
	local root = Kit.root(owner)
	if not root or flat(root.Position, match.data.start) > REACH then
		return
	end
	throwBall(match, match.data.start, match.data.finish)
	local character = Actors.characterOf(owner.actor) :: Model
	match.data.running[owner] = { phase = "out", model = character }
	SlipperService.registerTarget(character, function(thrower)
		local by = thrower and PlotService.getOwnerOfActor(thrower)
		if by and OinaRules.score(state, { kind = "hit", player = owner.userId, by = by.userId }) then
			stopRunner(match, owner)
			match.eliminate(owner)
			publish(match)
			if OinaRules.allOut(state) then
				swap(match)
			end
		end
	end, 2.5)
	publish(match)
end

function Oina.tick(match: any, _dt: number)
	local state = match.data.state
	for owner, run in match.data.running do
		local root = Kit.root(owner)
		if not root then
			stopRunner(match, owner)
			continue
		end
		if run.phase == "out" and flat(root.Position, match.data.finish) <= REACH then
			run.phase = "back"
		elseif run.phase == "back" and flat(root.Position, match.data.start) <= REACH then
			stopRunner(match, owner)
			if OinaRules.score(state, { kind = "run", player = owner.userId }) then
				match.score(owner, 0) -- momentul (pentru egalități); punctele sunt ale echipei
				publish(match)
			end
		end
	end
	local half = match.startedAt + (match.endsAt - match.startedAt) / 2
	if not match.data.swapped and workspace:GetServerTimeNow() >= half then
		swap(match)
	end
end

function Oina.finish(match: any): { [number]: number }
	for owner in match.data.running do
		stopRunner(match, owner)
	end
	local state = match.data.state
	local scores = {}
	for id, team in state.team do
		local multiplier = Minigame.cheerMultiplier(match.cheers[team] or 0)
		scores[id] = math.floor(state.points[team] * multiplier * 100)
	end
	return scores
end

return Oina
