--!strict
-- Cursa cu roaba (2–8 jucători, 90 s): de la biserica de pe deal, la vale, prin 6 porți, până la ulița de
-- deal. Cu roaba în față alergi mai repede la vale (viteză +40%); porțile se iau în ordine, scurtăturile și
-- ieșirile de pe traseu te duc înapoi la ultima poartă. Ordinea la sosire e clasamentul.

local Kit = require(script.Parent.Parent.Happenings.Kit)
local Actors = require(script.Parent.Parent.Actors)
local RaceKit = require(script.Parent.RaceKit)

local Roaba = {}

-- traseul (x, z) de la biserică spre uliță, cu cotituri; înălțimea se ia de pe teren
local POINTS = {
	Vector2.new(65, 310),
	Vector2.new(60, 290),
	Vector2.new(44, 268),
	Vector2.new(63, 246),
	Vector2.new(45, 224),
	Vector2.new(60, 204),
	Vector2.new(54, 188),
}

local function barrow(parent: Instance): Part
	local tray = Instance.new("Part")
	tray.Name = "Roaba"
	tray.Size = Vector3.new(2.4, 1, 3)
	tray.Color = Color3.fromRGB(70, 120, 180)
	tray.Material = Enum.Material.Metal
	tray.Massless = true
	tray.CanCollide = false
	tray.CanQuery = false
	tray.Parent = parent
	return tray
end

function Roaba.setup(match: any)
	local gates = {}
	for _, p in POINTS do
		table.insert(gates, Vector3.new(p.X, Kit.groundY(p.X, p.Y), p.Y))
	end
	match.data.gates = gates
	for i = 1, #gates do
		local facing = if i < #gates then gates[i + 1] - gates[i] else gates[i] - gates[i - 1]
		RaceKit.gate(
			i,
			gates[i],
			facing,
			match.folder,
			if i == #gates then Color3.fromRGB(240, 200, 60) else Color3.fromRGB(220, 70, 70)
		)
	end
	RaceKit.start(match, gates, 6, 22)
	-- roaba în fața fiecărui jucător și viteza la vale
	for _, owner in match.players do
		local root = Kit.root(owner)
		if root then
			local tray = barrow(match.folder)
			tray.CFrame = root.CFrame * CFrame.new(0, -1.6, -2.6)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = tray
			weld.Parent = tray
		end
		Kit.slow(owner, "barrow", 1.4, match.endsAt - match.startedAt + 5)
	end
	match.publish({})
end

function Roaba.gates(match: any): { Vector3 }
	return match.data.gates
end

function Roaba.tick(match: any, _dt: number)
	for _, owner in RaceKit.tick(match) do
		-- primul sosit ia cel mai mult
		match.score(owner, 100 - #match.data.finishOrder)
		match.publish({})
	end
	if #match.data.finishOrder >= #match.players then
		match.finish()
	end
end

function Roaba.finish(match: any): { [number]: number }
	for _, owner in match.players do
		if owner.actor and Actors.root(owner.actor) then
			Kit.slow(owner, "barrow", 1, 0.01)
		end
	end
	return match.scores
end

return Roaba
