--!strict
-- Obby-ul morii (1–8 jucători, 2 minute, pe deal): platforme în spirală în jurul morii, până sub pale; două bare
-- se rotesc și te împing de pe platformă. Fiecare platformă e o poartă; dacă pici, reapari pe ultima. Cine
-- ajunge sus mai repede ia mai multe puncte; cel mai bun scor de pe server apare pe avizier.

local RunService = game:GetService("RunService")

local Kit = require(script.Parent.Parent.Happenings.Kit)
local RaceKit = require(script.Parent.RaceKit)
local Records = require(script.Parent.Parent.Records)

local Moara = {}

local STEPS = 10
local RADIUS = 13
local RISE = 2.2
local WOOD = Color3.fromRGB(150, 104, 62)

local function platform(match: any, cf: CFrame, size: Vector3, name: string): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Color = WOOD
	p.Material = Enum.Material.WoodPlanks
	p.CFrame = cf
	p.Parent = match.folder
	return p
end

function Moara.setup(match: any)
	local center = match.arena.Position
	local base = Kit.groundY(center.X, center.Z)
	local gates = {}
	-- prima poartă: jos, în fața morii
	local start = Vector3.new(center.X, base, center.Z) + match.arena.LookVector * (RADIUS + 6)
	table.insert(gates, start)
	for i = 1, STEPS do
		local angle = i * 0.75
		local p = Vector3.new(
			center.X + math.cos(angle) * RADIUS,
			base + i * RISE + 1,
			center.Z + math.sin(angle) * RADIUS
		)
		platform(match, CFrame.new(p), Vector3.new(5, 0.8, 5), "Treapta" .. i)
		table.insert(gates, p + Vector3.new(0, 0.4, 0))
	end
	match.data.gates = gates
	-- barele care se rotesc, pe treptele 4 și 8 (CanCollide: împing)
	match.data.sweepers = {}
	for _, i in { 4, 8 } do
		local at = gates[i + 1]
		local bar =
			platform(match, CFrame.new(at + Vector3.new(0, 1.8, 0)), Vector3.new(9, 0.7, 0.7), "Bara" .. i)
		bar.Color = Color3.fromRGB(200, 60, 50)
		bar.Material = Enum.Material.SmoothPlastic
		table.insert(
			match.data.sweepers,
			{ part = bar, center = at + Vector3.new(0, 1.8, 0), speed = 1.4 + i * 0.05 }
		)
	end
	match.data.spin = RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, s in match.data.sweepers do
			if s.part.Parent then
				s.part.CFrame = CFrame.new(s.center) * CFrame.Angles(0, t * s.speed, 0)
			end
		end
	end)
	RaceKit.start(match, gates, 3.4, 40)
	match.publish({})
end

function Moara.gates(match: any): { Vector3 }
	return match.data.gates
end

function Moara.tick(match: any, _dt: number)
	local now = workspace:GetServerTimeNow()
	for _, owner in RaceKit.tick(match, 9) do
		local seconds = now - match.startedAt
		local score = math.max(1, math.floor(1200 - seconds * 10))
		match.score(owner, score)
		Records.submit("Moara", owner, score)
		match.publish({})
	end
	if #match.data.finishOrder >= #match.players then
		match.finish()
	end
end

function Moara.finish(match: any): { [number]: number }
	if match.data.spin then
		match.data.spin:Disconnect()
	end
	return match.scores
end

return Moara
